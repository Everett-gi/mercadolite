require "rails_helper"

RSpec.describe CartItem do
  let(:product) { create(:product, price_cents: 4_990, stock: 5) }

  it "é válido com os atributos da fábrica" do
    expect(build(:cart_item)).to be_valid
  end

  describe "quantidade" do
    [ 0, -1, CartItem::MAX_QUANTITY + 1 ].each do |invalid|
      it "recusa #{invalid}" do
        expect(build(:cart_item, quantity: invalid)).not_to be_valid
      end
    end

    it "é protegida pela check constraint do banco" do
      item = create(:cart_item)

      expect { item.update_column(:quantity, CartItem::MAX_QUANTITY + 1) }
        .to raise_error(ActiveRecord::StatementInvalid, /cart_items_quantity_range/)
    end

    it "não pode passar do estoque atual" do
      item = build(:cart_item, product:, quantity: 6)

      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to include("maior que o estoque (só restam 5 unidades)")
    end

    it "usa o singular quando resta uma unidade" do
      product.inventory.update!(quantity: 1)
      item = build(:cart_item, product:, quantity: 2)

      item.valid?
      expect(item.errors[:quantity]).to include("maior que o estoque (só resta 1 unidade)")
    end
  end

  it "recusa produto que não está mais à venda" do
    item = build(:cart_item, product: create(:product, :inactive, stock: 5))

    expect(item).not_to be_valid
    expect(item.errors[:product]).to include("não está mais à venda")
  end

  it "permite uma só linha por produto em cada carrinho (índice único)" do
    first = create(:cart_item, product:)
    duplicate = build(:cart_item, cart: first.cart, product:)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "#line_total_cents" do
    it "multiplica o preço ATUAL do produto pela quantidade" do
      item = create(:cart_item, product:, quantity: 2)
      expect(item.line_total_cents).to eq(9_980)

      product.update!(price_cents: 5_000)
      expect(item.reload.line_total_cents).to eq(10_000)
    end
  end

  describe "disponibilidade" do
    it "fica indisponível quando o produto é desativado depois" do
      item = create(:cart_item, product:)
      product.update!(active: false)

      expect(item.reload).not_to be_available
      expect(item).not_to be_purchasable
    end

    it "acusa quando o estoque baixou para menos que a quantidade" do
      item = create(:cart_item, product:, quantity: 4)
      product.inventory.update!(quantity: 2)

      expect(item.reload).to be_exceeds_stock
      expect(item).not_to be_purchasable
    end
  end

  it "atualiza o updated_at do carrinho ao mudar (touch)" do
    item = create(:cart_item)
    item.cart.update_column(:updated_at, 2.days.ago)

    expect { item.update!(quantity: 2) }.to(change { item.cart.reload.updated_at })
  end
end
