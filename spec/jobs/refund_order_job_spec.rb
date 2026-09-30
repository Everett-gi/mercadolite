require "rails_helper"

RSpec.describe RefundOrderJob do
  include ActiveJob::TestHelper

  let(:order) { create(:order, :refunding) }
  let(:refunds_url) { "#{StripeHelpers::API}/refunds" }

  def stub_refund(status: "succeeded")
    stub_request(:post, refunds_url).to_return(
      status: 200,
      body: { id: "re_test_1", object: "refund", status:, payment_intent: order.stripe_payment_intent_id }.to_json
    )
  end

  # Stripe-Should-Retry: false — a gem não repete sozinha; quem repete é o job.
  def stub_refund_error(http_status, type)
    stub_request(:post, refunds_url).to_return(
      status: http_status, headers: { "Stripe-Should-Retry" => "false" },
      body: { error: { type:, message: "erro de teste" } }.to_json
    )
  end

  it "estorna o pagamento inteiro do pedido, com chave de idempotência, e registra o estorno" do
    stub = stub_refund

    described_class.perform_now(order)

    expect(stub.with { |req|
      form = Rack::Utils.parse_nested_query(req.body)
      form["payment_intent"] == order.stripe_payment_intent_id &&
        form["metadata"] == { "order_id" => order.id.to_s } &&
        !form.key?("amount") && # sem valor: o Stripe estorna tudo o que foi pago
        req.headers["Idempotency-Key"] == "mercadolite-order-#{order.id}-refund"
    }).to have_been_made.once
    expect(order.reload).to have_attributes(status: "refunded", stripe_refund_id: "re_test_1")
  end

  it "não chama o Stripe para pedido que não está em estorno" do
    paid = create(:order, :paid)

    described_class.perform_now(paid)

    expect(a_request(:post, refunds_url)).not_to have_been_made
  end

  it "falha passageira do Stripe: agenda uma nova tentativa" do
    stub_refund_error(500, "api_error")

    expect { described_class.perform_now(order) }.to have_enqueued_job(described_class).with(order)
    expect(order.reload).to be_refunding
  end

  it "erro que não se resolve sozinho (chave sem permissão): o job falha, sem nova tentativa" do
    stub_refund_error(403, "invalid_request_error")

    expect { described_class.perform_now(order) }.to raise_error(Stripe::PermissionError)
    expect(enqueued_jobs).to be_empty
  end

  it "estorno que o Stripe não fez: registra erro e o pedido continua em estorno" do
    stub_refund(status: "failed")
    allow(Rails.logger).to receive(:error).and_call_original

    described_class.perform_now(order)

    expect(order.reload).to be_refunding
    expect(Rails.logger).to have_received(:error).with(/refund_not_accepted/)
  end
end
