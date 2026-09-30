require "rails_helper"

RSpec.describe ReconcileOrdersJob do
  include ActiveJob::TestHelper

  let(:product) { create(:product, stock: 5) }

  # Um pedido pendente criado há 2 horas: a página de pagamento (30 min) já expirou.
  def stale_order(**attrs)
    create(:order, product:, quantity: 1, created_at: 2.hours.ago, **attrs)
  end

  def stub_session(order, **overrides)
    stub_request(:get, "#{StripeHelpers::API}/checkout/sessions/#{order.stripe_checkout_session_id}")
      .to_return(status: 200, body: stripe_session_payload(order, **overrides).to_json)
  end

  # O caso que um "cancela tudo o que passou de 1 hora" erraria: o comprador pagou, mas o
  # webhook se perdeu (ou está atrasado).
  it "pedido pago cujo webhook não chegou: confirma, com baixa de estoque" do
    order = stale_order
    stub_session(order) # status "complete", payment_status "paid"

    expect(described_class.perform_now).to eq(paid: 1)

    expect(order.reload).to be_paid
    expect(product.inventory.reload.quantity).to eq(4)
  end

  it "sessão expirada: cancela" do
    order = stale_order
    stub_session(order, status: "expired", payment_status: "unpaid")

    expect(described_class.perform_now).to eq(canceled: 1)
    expect(order.reload).to be_canceled
  end

  it "sessão ainda aberta: não mexe" do
    order = stale_order
    stub_session(order, status: "open", payment_status: "unpaid")

    expect(described_class.perform_now).to eq(still_open: 1)
    expect(order.reload).to be_pending
  end

  it "pedido que nunca chegou ao Stripe: cancela sem chamar a API" do
    order = stale_order(stripe_checkout_session_id: nil)

    expect(described_class.perform_now).to eq(canceled: 1)
    expect(order.reload).to be_canceled
    expect(a_request(:get, /api.stripe.com/)).not_to have_been_made
  end

  it "pedido recente fica para o webhook: nenhuma consulta" do
    order = create(:order, product:, created_at: 10.minutes.ago)

    expect(described_class.perform_now).to eq({})
    expect(order.reload).to be_pending
    expect(a_request(:get, /api.stripe.com/)).not_to have_been_made
  end

  it "estorno parado há mais de 1 hora: pede de novo" do
    order = create(:order, :refunding, paid_at: 2.hours.ago)
    create(:order, :refunding, paid_at: 5.minutes.ago) # recente: o job ainda está tentando

    expect { expect(described_class.perform_now).to eq(refund_retried: 1) }
      .to have_enqueued_job(RefundOrderJob).with(order).exactly(:once)
  end

  it "um erro do Stripe num pedido não impede os outros" do
    broken = stale_order
    stub_request(:get, %r{/checkout/sessions/#{broken.stripe_checkout_session_id}})
      .to_return(status: 500, headers: { "Stripe-Should-Retry" => "false" },
                 body: { error: { type: "api_error", message: "erro de teste" } }.to_json)
    fine = stale_order
    stub_session(fine)

    expect(described_class.perform_now).to eq(stripe_error: 1, paid: 1)
    expect([ broken.reload.status, fine.reload.status ]).to eq(%w[pending paid])
  end

  # Achado no teste com o Stripe de verdade: pedidos cujas sessões são de outra conta do
  # Stripe (troca de chaves) dão erro em toda rodada. Se a fila começasse pelos mais antigos,
  # eles ocupariam o lote para sempre e os pedidos novos nunca seriam conciliados.
  it "um pedido que sempre dá erro não impede a conciliação dos mais novos" do
    stub_const("#{described_class}::BATCH_SIZE", 1)
    broken = stale_order(created_at: 3.hours.ago)
    stub_request(:get, %r{/checkout/sessions/#{broken.stripe_checkout_session_id}})
      .to_return(status: 404, body: { error: { type: "invalid_request_error", code: "resource_missing",
                                               message: "No such checkout.session" } }.to_json)
    newer = stale_order(created_at: 2.hours.ago)
    stub_session(newer)

    expect(described_class.perform_now).to eq(paid: 1)
    expect(newer.reload).to be_paid
  end

  # Uma sessão vive no máximo 24 horas no Stripe; depois de 3 dias, a resposta não muda mais.
  it "desiste de pedidos pendentes há mais de 3 dias (ficam para uma pessoa olhar)" do
    stale_order(created_at: 4.days.ago)

    expect(described_class.perform_now).to eq({})
    expect(a_request(:get, /api.stripe.com/)).not_to have_been_made
  end

  it "sem a chave do Stripe, não faz nada" do
    stale_order
    allow(StripeCheckout).to receive(:configured?).and_return(false)

    expect(described_class.perform_now).to eq({})
  end
end
