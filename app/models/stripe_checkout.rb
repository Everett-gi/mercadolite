# A conversa com a API do Stripe Checkout: criar a página de pagamento de um pedido e
# consultar como ela terminou. Não é um modelo do banco (é uma classe Ruby comum, um PORO:
# "plain old Ruby object"); fica em app/models por ser lógica de negócio.
class StripeCheckout
  # A página de pagamento expira em 30 minutos (o mínimo que o Stripe aceita; o padrão seria
  # 24 horas). Depois disso, o webhook "checkout.session.expired" cancela o pedido.
  EXPIRES_IN = 30.minutes
  # A URL da página de pagamento precisa ser do Stripe: o redirecionamento para fora da loja
  # só é liberado para este endereço.
  CHECKOUT_HOST = "checkout.stripe.com"

  # O Stripe responde algo inesperado (ex.: uma URL que não é dele).
  class UnexpectedResponse < StandardError; end

  # @return [Boolean] se a chave da API está configurada
  def self.configured?
    Rails.configuration.x.stripe.secret_key.present?
  end

  # @param client [Stripe::StripeClient]
  def initialize(client = Stripe::StripeClient.new(Rails.configuration.x.stripe.secret_key))
    @client = client
  end

  # Cria a sessão de pagamento do pedido e guarda o id dela no pedido.
  #
  # Os itens e os valores saem do PEDIDO (preços congelados do banco), nunca do navegador.
  #
  # @param order [Order] pendente, já salvo
  # @param success_url [String] para onde o Stripe manda o comprador depois de pagar
  # @param cancel_url [String] para onde ele volta se desistir
  # @return [String] a URL da página de pagamento (em checkout.stripe.com)
  def start(order, success_url:, cancel_url:)
    session = @client.v1.checkout.sessions.create(
      session_params(order, success_url:, cancel_url:),
      # Chave de idempotência: se este pedido pedir uma sessão duas vezes (um clique duplo,
      # uma nova tentativa), o Stripe devolve a MESMA sessão, em vez de criar outra.
      { idempotency_key: "mercadolite-order-#{order.id}-checkout" }
    )
    url = session.url.to_s
    raise UnexpectedResponse, "URL de pagamento fora do Stripe" unless URI(url).host == CHECKOUT_HOST

    order.update!(stripe_checkout_session_id: session.id)
    url
  end

  # Consulta a sessão do pedido na API e aplica o resultado (paga, expirada ou ainda aberta).
  # Usado na página de retorno, para o comprador não esperar o webhook, e na conciliação
  # (ReconcileOrdersJob). É a mesma confirmação idempotente do webhook: o que chegar primeiro
  # vale, o segundo não muda nada.
  #
  # @param order [Order] com a sessão de pagamento já criada
  # @return [Symbol] o resultado de Order#apply_checkout_session!
  def sync(order)
    session = @client.v1.checkout.sessions.retrieve(order.stripe_checkout_session_id)
    order.apply_checkout_session!(session)
  end

  private

  def session_params(order, success_url:, cancel_url:)
    {
      mode: "payment",
      # Só cartão: o pagamento é confirmado na hora. (Boleto e Pix confirmam depois, e o
      # pedido ficaria "processando" por dias.)
      payment_method_types: [ "card" ],
      line_items: order.items.map do |item|
        {
          quantity: item.quantity,
          price_data: {
            currency: Order::CURRENCY,
            unit_amount: item.unit_price_cents,
            product_data: { name: item.product_name }
          }
        }
      end,
      # Liga a sessão ao pedido nos dois sentidos (e aparece no painel do Stripe).
      client_reference_id: order.id.to_s,
      metadata: { order_id: order.id.to_s },
      # O e-mail da conta já preenchido. O Stripe precisa de um e-mail para o recibo.
      customer_email: order.user.email,
      locale: "pt-BR",
      expires_at: EXPIRES_IN.from_now.to_i,
      success_url:,
      cancel_url:
    }
  end
end
