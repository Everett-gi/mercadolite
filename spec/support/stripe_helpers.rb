# Ferramentas dos testes de pagamento: montam o que o Stripe mandaria (uma sessão de
# checkout, um evento de webhook ASSINADO) sem nenhuma chamada de rede.
module StripeHelpers
  API = "https://api.stripe.com/v1".freeze

  # Uma sessão de checkout como o Stripe devolve, já com os dados do pedido.
  #
  # @return [Hash]
  def stripe_session_payload(order, **overrides)
    {
      id: order.stripe_checkout_session_id,
      object: "checkout.session",
      url: "https://checkout.stripe.com/c/pay/#{order.stripe_checkout_session_id}",
      payment_status: "paid",
      status: "complete",
      amount_total: order.total_cents,
      currency: "brl",
      payment_intent: "pi_test_#{order.id}",
      client_reference_id: order.id.to_s
    }.merge(overrides)
  end

  # O corpo de um evento de webhook (JSON), como o Stripe envia.
  #
  # @return [String]
  def stripe_event_json(type:, object:, id: "evt_test_#{SecureRandom.hex(8)}")
    { id:, object: "event", type:, created: Time.now.to_i, livemode: false, data: { object: } }.to_json
  end

  # O cabeçalho Stripe-Signature: t=<quando>,v1=<HMAC-SHA256 de "quando.corpo" com o segredo>.
  #
  # @return [String]
  def stripe_signature(payload, secret: Rails.configuration.x.stripe.webhook_secret, at: Time.now)
    signature = Stripe::Webhook::Signature.compute_signature(at, payload, secret)
    Stripe::Webhook::Signature.generate_header(at, signature)
  end

  # Envia o webhook como o Stripe faria.
  def post_stripe_webhook(payload, signature: stripe_signature(payload), headers: {})
    post stripe_webhook_path, params: payload,
         headers: { "Content-Type" => "application/json", "Stripe-Signature" => signature }.merge(headers)
  end
end

RSpec.configure do |config|
  config.include StripeHelpers
end
