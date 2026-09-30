# A conversa com a API de estornos do Stripe. Como o StripeCheckout, é um PORO (classe Ruby
# comum, sem tabela), com o cliente da API recebido no construtor.
class StripeRefunds
  # @param client [Stripe::StripeClient]
  def initialize(client = Stripe::StripeClient.new(Rails.configuration.x.stripe.secret_key))
    @client = client
  end

  # Estorna o valor inteiro do pagamento do pedido.
  #
  # @param order [Order] em "refunding", com o id do pagamento
  # @return [Stripe::Refund]
  def refund_in_full(order)
    @client.v1.refunds.create(
      { payment_intent: order.stripe_payment_intent_id, metadata: { order_id: order.id.to_s } },
      # Uma chave por pedido: uma nova tentativa (do job, da gem ou da conciliação) recebe o
      # MESMO estorno, e não um segundo.
      { idempotency_key: "mercadolite-order-#{order.id}-refund" }
    )
  end
end
