# Recebe os webhooks do Stripe: avisos, servidor a servidor, de que algo aconteceu (um
# pagamento confirmado, uma sessão de pagamento que expirou).
#
# Herda de ActionController::API, e não do ApplicationController: quem chama é o servidor
# do Stripe, e não um navegador. Não há sessão, cookie nem token CSRF (a proteção CSRF do
# ApplicationController responderia 422 a todo webhook). A autenticidade vem da ASSINATURA,
# conferida abaixo, que é mais forte que o token: prova quem mandou E que o corpo não mudou.
class StripeWebhooksController < ActionController::API
  # Um evento de checkout tem poucos KB. Corpo maior que isso é recusado antes de qualquer
  # processamento.
  MAX_PAYLOAD_BYTES = 64.kilobytes

  # POST /webhooks/stripe
  def create
    payload = request.body.read(MAX_PAYLOAD_BYTES + 1).to_s
    return head(:content_too_large) if payload.bytesize > MAX_PAYLOAD_BYTES

    # Confere a assinatura HMAC-SHA256 do corpo EXATO (por isso o corpo cru, sem passar por
    # um parser) e a idade do evento: com mais de 5 minutos, é recusado (contra replay).
    event = Stripe::Webhook.construct_event(
      payload, request.headers["Stripe-Signature"].to_s, Rails.configuration.x.stripe.webhook_secret
    )
    result = StripeEvent.process(event)
    log(event, result)
    # 200 para tudo o que foi verificado, inclusive o que ignoramos: se não, o Stripe reenviaria
    # o mesmo evento por dias.
    head :ok
  rescue Stripe::SignatureVerificationError, JSON::ParserError
    # Sem detalhes na resposta: quem forjou o pedido não aprende nada.
    head :bad_request
  end

  private

  # Registra o que aconteceu, sem o conteúdo do evento (que tem o e-mail do comprador).
  def log(event, result)
    level = result.in?(%i[amount_mismatch currency_mismatch session_mismatch]) ? :error : :info
    Rails.logger.public_send(level, "[stripe] #{event.type} #{event.id}: #{result}")
  end
end
