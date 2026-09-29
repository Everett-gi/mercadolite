require "rails_helper"

RSpec.describe StripeEvent do
  let(:order) { create(:order) }

  # @param session [Hash] campos da sessão que mudam em relação ao pedido
  def event(type, id: "evt_test_1", session: {})
    Stripe::Event.construct_from(JSON.parse(
      stripe_event_json(type:, id:, object: stripe_session_payload(order, **session))
    ))
  end

  it "confirma o pagamento no checkout.session.completed" do
    expect(described_class.process(event("checkout.session.completed"))).to eq(:paid)
    expect(order.reload).to be_paid
  end

  it "processa cada evento uma vez só: o reenvio do mesmo evento é ignorado" do
    completed = event("checkout.session.completed")
    described_class.process(completed)

    expect(described_class.process(completed)).to eq(:duplicate)
    expect(described_class.where(event_id: completed.id).count).to eq(1)
  end

  it "um evento diferente para a mesma sessão também não paga duas vezes" do
    described_class.process(event("checkout.session.completed", id: "evt_test_1"))
    paid_at = order.reload.paid_at

    result = described_class.process(event("checkout.session.async_payment_succeeded", id: "evt_test_2"))

    expect(result).to eq(:already_processed)
    expect(order.reload.paid_at).to eq(paid_at)
  end

  it "cancela o pedido quando a sessão de pagamento expira" do
    expect(described_class.process(event("checkout.session.expired", session: { status: "expired" }))).to eq(:canceled)
    expect(order.reload).to be_canceled
  end

  it "ignora tipos de evento que não usamos" do
    expect(described_class.process(event("customer.created"))).to eq(:ignored)
  end

  it "responde :order_not_found para uma sessão que não é de nenhum pedido" do
    expect(described_class.process(event("checkout.session.completed", session: { id: "cs_test_de_ninguem" })))
      .to eq(:order_not_found)
  end

  # Se o efeito falhar, o registro do evento some junto (mesma transação): o Stripe reenvia,
  # e o reenvio é processado de verdade, e não descartado como "duplicado".
  it "se o processamento falhar, o evento não fica marcado como processado" do
    completed = event("checkout.session.completed")
    allow_any_instance_of(Order).to receive(:confirm_payment!).and_raise(ActiveRecord::ConnectionTimeoutError)

    expect { described_class.process(completed) }.to raise_error(ActiveRecord::ConnectionTimeoutError)
    expect(described_class.exists?(event_id: completed.id)).to be(false)
  end
end
