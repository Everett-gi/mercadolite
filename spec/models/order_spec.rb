require "rails_helper"

RSpec.describe Order do
  let(:user) { create(:user) }
  let(:mug) { create(:product, name: "Caneca azul", price_cents: 4_990, stock: 10) }
  let(:teapot) { create(:product, name: "Bule", price_cents: 12_950, stock: 3) }

  def cart_with(*lines)
    create(:cart, user:).tap do |cart|
      lines.each { |product, quantity| cart.add(product, quantity) }
    end
  end

  describe ".place" do
    it "cria o pedido com nome e preço copiados do banco, e o total calculado" do
      order = described_class.place(cart_with([ mug, 2 ], [ teapot, 1 ]), user)

      expect(order).to be_persisted.and be_pending
      expect(order.user).to eq(user)
      expect(order.items.map { |i| [ i.product_name, i.unit_price_cents, i.quantity ] })
        .to contain_exactly([ "Caneca azul", 4_990, 2 ], [ "Bule", 12_950, 1 ])
      expect(order.total_cents).to eq(2 * 4_990 + 12_950)
    end

    it "congela o preço: mudar o produto depois não muda o pedido" do
      order = described_class.place(cart_with([ mug, 1 ]), user)

      mug.update!(name: "Caneca nova", price_cents: 9_999)

      expect(order.reload.items.sole).to have_attributes(product_name: "Caneca azul", unit_price_cents: 4_990)
      expect(order.total_cents).to eq(4_990)
    end

    it "recusa carrinho vazio (ou inexistente)" do
      expect(described_class.place(nil, user).errors[:base]).to include("Seu carrinho está vazio.")
      expect(described_class.place(create(:cart, user:), user)).not_to be_persisted
    end

    it "recusa carrinho com item indisponível" do
      cart = cart_with([ mug, 2 ], [ teapot, 1 ])
      teapot.update!(active: false)

      order = described_class.place(cart, user)

      expect(order).not_to be_persisted
      expect(order.errors[:base].first).to start_with("Há itens indisponíveis")
    end

    it "recusa carrinho com mais unidades que o estoque atual" do
      cart = cart_with([ teapot, 3 ])
      teapot.inventory.update!(quantity: 1)

      expect(described_class.place(cart, user)).not_to be_persisted
    end
  end

  describe "#confirm_payment!" do
    let(:order) { create(:order, user:, product: mug, quantity: 2) }
    let(:session) { Stripe::Checkout::Session.construct_from(stripe_session_payload(order)) }

    it "marca como pago, com a data e o id do pagamento" do
      freeze_time do
        expect(order.confirm_payment!(session)).to eq(:paid)

        expect(order.reload).to have_attributes(status: "paid", paid_at: Time.current,
                                                stripe_payment_intent_id: "pi_test_#{order.id}")
      end
    end

    it "é idempotente: a segunda confirmação não muda nada" do
      order.confirm_payment!(session)
      paid_at = order.reload.paid_at

      travel 1.minute do
        expect(order.confirm_payment!(session)).to eq(:already_processed)
      end
      expect(order.reload.paid_at).to eq(paid_at)
    end

    {
      "sessão de outro pedido" => [ { id: "cs_test_outra" }, :session_mismatch ],
      "pagamento ainda não feito" => [ { payment_status: "unpaid" }, :not_paid ],
      "valor diferente do pedido" => [ { amount_total: 1 }, :amount_mismatch ],
      "moeda diferente" => [ { currency: "usd" }, :currency_mismatch ]
    }.each do |label, (overrides, reason)|
      it "recusa #{label} e deixa o pedido pendente" do
        forged = Stripe::Checkout::Session.construct_from(stripe_session_payload(order, **overrides))

        expect(order.confirm_payment!(forged)).to eq(reason)
        expect(order.reload).to be_pending
      end
    end

    it "tira do carrinho só os produtos comprados" do
      cart = cart_with([ mug, 2 ], [ teapot, 1 ])
      order = described_class.place(cart, user)
      order.update!(stripe_checkout_session_id: "cs_test_carrinho")
      # Adicionado DEPOIS de ir para o pagamento: não faz parte do pedido e fica no carrinho.
      pen = create(:product, name: "Caneta", stock: 5)
      cart.add(pen, 1)

      order.confirm_payment!(Stripe::Checkout::Session.construct_from(stripe_session_payload(order)))

      expect(cart.items.reload.map(&:product)).to eq([ pen ])
    end
  end

  describe "#cancel_checkout!" do
    let(:order) { create(:order, user:) }
    let(:session) { Stripe::Checkout::Session.construct_from(stripe_session_payload(order, status: "expired")) }

    it "cancela o pedido pendente, uma vez só" do
      expect(order.cancel_checkout!(session)).to eq(:canceled)
      expect(order.reload).to be_canceled
      expect(order.cancel_checkout!(session)).to eq(:already_processed)
    end

    it "não cancela com a sessão de outro pedido" do
      other = Stripe::Checkout::Session.construct_from(stripe_session_payload(order, id: "cs_test_outra"))

      expect(order.cancel_checkout!(other)).to eq(:already_processed)
      expect(order.reload).to be_pending
    end

    it "não cancela pedido já pago" do
      paid = create(:order, :paid, user:)
      expired = Stripe::Checkout::Session.construct_from(stripe_session_payload(paid))

      expect(paid.cancel_checkout!(expired)).to eq(:already_processed)
      expect(paid.reload).to be_paid
    end
  end

  describe "restrições no banco" do
    let(:order) { create(:order, user:) }

    it "recusa status fora da lista" do
      expect { order.update_column(:status, "refunded") }
        .to raise_error(ActiveRecord::StatementInvalid, /orders_status_valid/)
    end

    it "recusa pedido pago sem data de pagamento" do
      expect { order.update_column(:status, "paid") }
        .to raise_error(ActiveRecord::StatementInvalid, /orders_paid_has_date/)
    end

    # Um teste por violação: depois de um erro, o PostgreSQL recusa qualquer outro comando na
    # mesma transação ("current transaction is aborted") até o rollback.
    it "recusa total zero" do
      expect { order.update_column(:total_cents, 0) }.to raise_error(ActiveRecord::StatementInvalid, /orders_total_positive/)
    end

    it "recusa moeda que não seja real" do
      expect { order.update_column(:currency, "usd") }.to raise_error(ActiveRecord::StatementInvalid, /orders_currency_brl/)
    end

    it "recusa item com quantidade fora de 1..10" do
      expect { order.items.first.update_column(:quantity, 11) }
        .to raise_error(ActiveRecord::StatementInvalid, /order_items_quantity_range/)
    end

    it "não deixa a mesma sessão do Stripe em dois pedidos" do
      expect { create(:order, stripe_checkout_session_id: order.stripe_checkout_session_id) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "exclusão de conta (LGPD)" do
    it "o pedido fica, mas sem dono" do
      order = create(:order, :paid, user:)

      user.destroy!

      expect(order.reload.user_id).to be_nil
      expect(order.items).to be_present
    end
  end

  it "um produto já vendido não pode ser apagado" do
    order = create(:order, product: mug)

    expect(mug.destroy).to be(false)
    expect(mug.errors[:base]).to be_present
    expect(Product.exists?(mug.id)).to be(true)
    expect(order.reload.items).to be_present
  end
end
