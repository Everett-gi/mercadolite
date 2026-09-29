require "rails_helper"

RSpec.describe "Webhooks do Stripe", type: :request do
  let(:user) { create(:user) }
  let(:order) { create(:order, user:) }
  let(:completed) { stripe_event_json(type: "checkout.session.completed", object: stripe_session_payload(order)) }

  it "com a assinatura certa, confirma o pagamento" do
    post_stripe_webhook(completed)

    expect(response).to have_http_status(:ok)
    expect(order.reload).to be_paid
  end

  describe "assinatura" do
    it "recusa (400) corpo alterado depois de assinado" do
      signature = stripe_signature(completed)
      tampered = completed.sub(%("amount_total":#{order.total_cents}), %("amount_total":1))

      post_stripe_webhook(tampered, signature:)

      expect(response).to have_http_status(:bad_request)
      expect(order.reload).to be_pending
    end

    it "recusa (400) sem o cabeçalho Stripe-Signature" do
      post_stripe_webhook(completed, signature: "")

      expect(response).to have_http_status(:bad_request)
      expect(order.reload).to be_pending
    end

    it "recusa (400) assinatura feita com outro segredo" do
      post_stripe_webhook(completed, signature: stripe_signature(completed, secret: "whsec_doatacante"))

      expect(response).to have_http_status(:bad_request)
    end

    # Replay: alguém que capturou um webhook legítimo tenta reenviá-lo mais tarde.
    it "recusa (400) evento assinado há mais de 5 minutos" do
      post_stripe_webhook(completed, signature: stripe_signature(completed, at: 6.minutes.ago))

      expect(response).to have_http_status(:bad_request)
      expect(order.reload).to be_pending
    end

    it "aceita evento assinado há menos de 5 minutos" do
      post_stripe_webhook(completed, signature: stripe_signature(completed, at: 4.minutes.ago))

      expect(order.reload).to be_paid
    end
  end

  describe "idempotência" do
    it "o mesmo evento entregue duas vezes é processado uma vez só" do
      post_stripe_webhook(completed)
      paid_at = order.reload.paid_at

      travel 1.minute do
        post_stripe_webhook(completed) # nova assinatura, mesmo evento
      end

      expect(response).to have_http_status(:ok) # 200: senão o Stripe reenviaria de novo
      expect(order.reload.paid_at).to eq(paid_at)
      expect(StripeEvent.count).to eq(1)
    end
  end

  it "valor diferente do pedido: responde 200, mas NÃO confirma, e registra erro no log" do
    forged = stripe_event_json(type: "checkout.session.completed", object: stripe_session_payload(order, amount_total: 1))
    allow(Rails.logger).to receive(:error).and_call_original

    post_stripe_webhook(forged)

    expect(response).to have_http_status(:ok)
    expect(order.reload).to be_pending
    expect(Rails.logger).to have_received(:error).with(/amount_mismatch/)
  end

  it "sessão expirada cancela o pedido" do
    expired = stripe_event_json(type: "checkout.session.expired", object: stripe_session_payload(order, status: "expired"))

    post_stripe_webhook(expired)

    expect(order.reload).to be_canceled
  end

  it "evento de tipo que não usamos: 200 e nada muda" do
    post_stripe_webhook(stripe_event_json(type: "customer.created", object: { id: "cus_test_1", object: "customer" }))

    expect(response).to have_http_status(:ok)
    expect(order.reload).to be_pending
  end

  it "recusa (413) corpo maior que 64 KB, antes de conferir qualquer coisa" do
    huge = stripe_event_json(type: "checkout.session.completed", object: stripe_session_payload(order, padding: "x" * 70_000))

    post_stripe_webhook(huge)

    expect(response).to have_http_status(:content_too_large)
    expect(order.reload).to be_pending
  end

  # O Stripe não é um navegador: sem cookie, sem token CSRF, com um User-Agent próprio.
  describe "chamado por um servidor" do
    include_context "com proteção CSRF ligada"

    it "funciona sem token CSRF e com o User-Agent do Stripe, e não cria sessão" do
      post_stripe_webhook(completed, headers: { "User-Agent" => "Stripe/1.0 (+https://stripe.com/docs/webhooks)" })

      expect(response).to have_http_status(:ok)
      expect(order.reload).to be_paid
      expect(response.headers["Set-Cookie"]).to be_nil
    end
  end
end
