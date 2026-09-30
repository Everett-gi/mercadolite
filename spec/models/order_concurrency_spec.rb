require "rails_helper"

# Concorrência DE VERDADE: duas conexões com o banco, em duas threads, disputando o mesmo
# pedido (como dois webhooks do Stripe que chegam juntos) ou o mesmo estoque (dois
# compradores pagando pela última unidade).
#
# Estes testes não rodam dentro de uma transação, como os outros: a transação do teste
# esconderia os dados da outra conexão, e a trava (SELECT ... FOR UPDATE) não teria contra
# quem valer. Por isso, cada teste apaga no fim o que criou.
RSpec.describe Order, "concorrência" do
  self.use_transactional_tests = false

  let(:first_paid_at) { Time.zone.local(2026, 9, 29, 12, 0, 0) }

  # Apaga os pedidos e tudo o que as fábricas criaram para eles.
  def destroy_orders(*orders)
    products = orders.flat_map { |order| order.items.map(&:product) }.uniq
    users = orders.map(&:user).uniq
    orders.each(&:destroy!)
    products.each { |product| product.destroy! && product.vendor.destroy! }
    users.each(&:destroy!)
  end

  def session_for(order, **overrides)
    Stripe::Checkout::Session.construct_from(stripe_session_payload(order, **overrides))
  end

  describe "o mesmo pedido" do
    let!(:order) { create(:order) }

    after { destroy_orders(order) }

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
      result = while_another_connection_pays { |stale| stale.confirm_payment!(session_for(order)) }

      expect(result).to eq(:already_processed)
      expect(order.reload).to have_attributes(status: "paid", paid_at: first_paid_at,
                                              stripe_payment_intent_id: "pi_primeiro")
    end

    it "cancel_checkout! que chega junto com o pagamento não cancela o pedido pago" do
      result = while_another_connection_pays { |stale| stale.cancel_checkout!(session_for(order, status: "expired")) }

      expect(result).to eq(:already_processed)
      expect(order.reload).to have_attributes(status: "paid", canceled_at: nil)
    end
  end

  describe "a última unidade" do
    let(:product) { create(:product, stock: 1) }
    let!(:first) { create(:order, product:, quantity: 1) }
    let!(:second) { create(:order, product:, quantity: 1) }

    after { destroy_orders(first, second) }

    # Os dois pagamentos foram aprovados pelo Stripe. A outra conexão confirma o primeiro
    # (baixando a última unidade) e só faz o COMMIT depois de 0,3 s; enquanto isso, esta
    # conexão confirma o segundo.
    it "um comprador leva a unidade; o outro recebe o estorno, e o estoque não fica negativo" do
      withdrawn = Queue.new
      other = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Order.transaction do
            result = first.confirm_payment!(session_for(first))
            withdrawn << true
            sleep 0.3
            result
          end
        end
      end
      withdrawn.pop

      second_result = second.confirm_payment!(session_for(second))

      expect([ other.value, second_result ]).to eq([ :paid, :out_of_stock ])
      expect(product.inventory.reload.quantity).to eq(0)
      expect([ first.reload.status, second.reload.status ]).to eq(%w[paid refunding])
    end
  end
end
