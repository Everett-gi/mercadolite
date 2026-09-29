require "rails_helper"

# Concorrência DE VERDADE: duas conexões com o banco, em duas threads, disputando o mesmo
# pedido (como dois webhooks do Stripe que chegam juntos).
#
# Estes testes não rodam dentro de uma transação, como os outros: a transação do teste
# esconderia os dados da outra conexão, e a trava (SELECT ... FOR UPDATE) não teria contra
# quem valer. Por isso, cada teste apaga no fim o que criou.
RSpec.describe Order, "concorrência" do
  self.use_transactional_tests = false

  let!(:order) { create(:order) }
  let(:first_paid_at) { Time.zone.local(2026, 9, 29, 12, 0, 0) }

  after do
    product = order.items.first.product
    user = order.user
    order.destroy!
    product.destroy!
    product.vendor.destroy!
    user.destroy!
  end

  # Outra conexão trava a linha do pedido, grava o pagamento e só faz o COMMIT depois de
  # 0,3 s. O bloco roda enquanto a linha está travada, com o pedido lido ANTES do commit
  # (ainda "pending" na memória).
  def while_another_connection_pays
    locked = Queue.new
    other = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Order.transaction do
          row = Order.lock.find(order.id)
          locked << true
          sleep 0.3
          row.update!(status: "paid", paid_at: first_paid_at, stripe_payment_intent_id: "pi_primeiro")
        end
      end
    end
    locked.pop
    result = yield Order.find(order.id)
    other.join
    result
  end

  it "confirm_payment! espera a outra confirmação terminar e não paga duas vezes" do
    session = Stripe::Checkout::Session.construct_from(stripe_session_payload(order))

    result = while_another_connection_pays { |stale| stale.confirm_payment!(session) }

    expect(result).to eq(:already_processed)
    expect(order.reload).to have_attributes(status: "paid", paid_at: first_paid_at,
                                            stripe_payment_intent_id: "pi_primeiro")
  end

  it "cancel_checkout! que chega junto com o pagamento não cancela o pedido pago" do
    session = Stripe::Checkout::Session.construct_from(stripe_session_payload(order, status: "expired"))

    result = while_another_connection_pays { |stale| stale.cancel_checkout!(session) }

    expect(result).to eq(:already_processed)
    expect(order.reload).to have_attributes(status: "paid", canceled_at: nil)
  end
end
