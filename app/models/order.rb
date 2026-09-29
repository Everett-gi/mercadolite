# Pedido: o que o comprador decidiu pagar, com os preços "congelados" na hora (OrderItem).
#
# Ciclo de vida:
#
#   pending ──(webhook: pagamento confirmado)──► paid ──(vendedor envia, fase 5)──► shipped
#      └────(webhook: sessão de pagamento expirou ou falhou)──► canceled
#
# Quem muda o status para "paid" é SÓ a confirmação do Stripe (webhook assinado ou consulta à
# API), nunca o navegador: a página de retorno do Stripe pode ser aberta por qualquer um.
class Order < ApplicationRecord
  STATUSES = %w[pending paid shipped canceled].freeze
  CURRENCY = "brl"

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

  # Confirma o pagamento a partir da sessão do Stripe (vinda de um webhook assinado ou de uma
  # consulta à API). Pode ser chamado várias vezes, até ao mesmo tempo, para a mesma sessão:
  # só a primeira chamada muda o pedido (idempotência).
  #
  # @param session [Stripe::Checkout::Session]
  # @return [Symbol] :paid, :already_processed ou o motivo da recusa (:session_mismatch,
  #   :not_paid, :amount_mismatch, :currency_mismatch)
  def confirm_payment!(session)
    result = nil
    # with_lock: SELECT ... FOR UPDATE. Relê o pedido travando a linha; uma segunda confirmação
    # simultânea espera esta terminar e então enxerga o status já atualizado.
    with_lock do
      result = if !pending?
        :already_processed
      else
        payment_problem(session) || :paid
      end
      update!(status: "paid", paid_at: Time.current, stripe_payment_intent_id: session.payment_intent) if result == :paid
    end
    remove_purchased_items_from_cart if result == :paid
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

  private

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
