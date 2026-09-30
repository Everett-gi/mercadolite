# Pedido: o que o comprador decidiu pagar, com os preços "congelados" na hora (OrderItem).
#
# Ciclo de vida:
#
#   pending ──(pago, com estoque: baixa)──► paid ──(vendedor envia, fase 5)──► shipped
#      ├────(pago, SEM estoque)──► refunding ──(o Stripe aceita o estorno)──► refunded
#      └────(a sessão de pagamento expirou ou falhou, ou nem foi criada)──► canceled
#
# Quem muda o status para "paid" é SÓ a confirmação do Stripe (webhook assinado ou consulta à
# API), nunca o navegador: a página de retorno do Stripe pode ser aberta por qualquer um.
class Order < ApplicationRecord
  STATUSES = %w[pending paid shipped canceled refunding refunded].freeze
  CURRENCY = "brl"
  # Estados de um estorno que o Stripe aceitou: "pending" (o dinheiro está a caminho do
  # cartão) ou "succeeded". Nos outros ("failed", "canceled", "requires_action"), nada voltou.
  REFUND_ACCEPTED = %w[pending succeeded].freeze

  # optional: true só por causa da exclusão de conta (o pedido fica, sem dono). Na criação,
  # o dono é obrigatório (validação abaixo).
  belongs_to :user, optional: true
  has_many :items, class_name: "OrderItem", dependent: :delete_all

  # enum: cria pending?, paid!, Order.paid (escopo) etc. validate: true — status fora da
  # lista vira erro de validação, e não exceção.
  enum :status, STATUSES.index_with(&:itself), default: "pending", validate: true

  validates :user, presence: true, on: :create
  validates :total_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, inclusion: { in: [ CURRENCY ] }
  validates :items, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  # Cria o pedido a partir do carrinho, com nome e preço lidos AGORA do banco. O preço nunca
  # vem do navegador (nem do carrinho, que não guarda preço).
  #
  # @param cart [Cart, nil]
  # @param user [User]
  # @return [Order] salvo; se não deu, order.errors diz o motivo
  def self.place(cart, user)
    order = new(user:)
    lines = cart ? cart.lines.to_a : []

    if lines.empty?
      order.errors.add(:base, :empty_cart)
    elsif lines.any? { |line| !line.purchasable? }
      order.errors.add(:base, :unavailable_items)
    else
      lines.each do |line|
        order.items.build(product: line.product, product_name: line.product.name,
                          unit_price_cents: line.product.price_cents, quantity: line.quantity)
      end
      order.total_cents = order.items.sum(&:line_total_cents)
      order.save
    end
    order
  end

  # Aplica ao pedido o estado da sessão de pagamento consultada na API do Stripe (na volta do
  # comprador e na conciliação).
  #
  # @param session [Stripe::Checkout::Session]
  # @return [Symbol] o resultado de confirm_payment! ou de cancel_checkout!, ou :still_open
  def apply_checkout_session!(session)
    case session.status
    when "complete" then confirm_payment!(session)
    when "expired" then cancel_checkout!(session)
    else :still_open
    end
  end

  # Confirma o pagamento a partir da sessão do Stripe (vinda de um webhook assinado ou de uma
  # consulta à API) e dá baixa no estoque. Pode ser chamado várias vezes, até ao mesmo tempo,
  # para a mesma sessão: só a primeira chamada muda o pedido (idempotência), e a baixa
  # acontece na mesma transação da mudança de status (nunca duas vezes).
  #
  # @param session [Stripe::Checkout::Session]
  # @return [Symbol] :paid, :out_of_stock (pago, mas sem estoque: vai para estorno),
  #   :already_processed ou o motivo da recusa (:session_mismatch, :not_paid,
  #   :amount_mismatch, :currency_mismatch)
  def confirm_payment!(session)
    result = nil
    # with_lock: SELECT ... FOR UPDATE. Relê o pedido travando a linha; uma segunda confirmação
    # simultânea espera esta terminar e então enxerga o status já atualizado.
    with_lock do
      result = if !pending?
        :already_processed
      else
        payment_problem(session) || settle_payment(session)
      end
    end

    case result
    when :paid then remove_purchased_items_from_cart
    when :out_of_stock
      # Depois do COMMIT: o job precisa encontrar o pedido já em "refunding" (e, se a
      # transação desfizer tudo, nenhum estorno é pedido).
      ActiveRecord.after_all_transactions_commit { RefundOrderJob.perform_later(self) }
    end
    result
  end

  # Cancela o pedido cuja sessão de pagamento expirou ou falhou. Idempotente, como a
  # confirmação.
  #
  # @param session [Stripe::Checkout::Session]
  # @return [Symbol] :canceled ou :already_processed
  def cancel_checkout!(session)
    result = :already_processed
    with_lock do
      if pending? && session.id == stripe_checkout_session_id
        update!(status: "canceled", canceled_at: Time.current)
        result = :canceled
      end
    end
    result
  end

  # Cancela o pedido que nunca chegou ao Stripe (a sessão de pagamento não foi criada).
  # Idempotente.
  #
  # @return [Symbol] :canceled ou :already_processed
  def cancel_unstarted!
    result = :already_processed
    with_lock do
      if pending? && stripe_checkout_session_id.nil?
        update!(status: "canceled", canceled_at: Time.current)
        result = :canceled
      end
    end
    result
  end

  # Registra o estorno criado no Stripe. Idempotente.
  #
  # @param refund [Stripe::Refund]
  # @return [Symbol] :refunded, :already_processed ou :refund_not_accepted (o Stripe não
  #   devolveu o dinheiro; o pedido continua em "refunding")
  def record_refund!(refund)
    return :refund_not_accepted unless REFUND_ACCEPTED.include?(refund.status)

    result = :already_processed
    with_lock do
      if refunding?
        update!(status: "refunded", refunded_at: Time.current, stripe_refund_id: refund.id)
        result = :refunded
      end
    end
    result
  end

  private

  # Pagamento conferido: dá baixa no estoque e marca "paid". Se faltar estoque para algum
  # item (outro comprador levou a última unidade entre o checkout e o pagamento), não baixa
  # nada e marca "refunding": o dinheiro volta ao comprador. Roda dentro do with_lock.
  #
  # @return [Symbol] :paid ou :out_of_stock
  def settle_payment(session)
    in_stock = Inventory.withdraw(items.to_h { |item| [ item.product_id, item.quantity ] })
    update!(status: in_stock ? "paid" : "refunding", paid_at: Time.current,
            stripe_payment_intent_id: session.payment_intent)
    in_stock ? :paid : :out_of_stock
  end

  # Defesa em profundidade: mesmo com a assinatura válida, o pagamento precisa bater com o
  # pedido (a mesma sessão, pago, o mesmo valor e a mesma moeda).
  #
  # @return [Symbol, nil]
  def payment_problem(session)
    if session.id != stripe_checkout_session_id
      :session_mismatch
    elsif session.payment_status != "paid"
      :not_paid
    elsif session.amount_total != total_cents
      :amount_mismatch
    elsif session.currency != CURRENCY
      :currency_mismatch
    end
  end

  # Tira do carrinho do comprador os produtos que ele acabou de pagar (o que ele tiver
  # adicionado depois de ir para o pagamento continua lá).
  def remove_purchased_items_from_cart
    cart = user&.cart
    cart&.items&.where(product_id: items.select(:product_id))&.delete_all
  end
end
