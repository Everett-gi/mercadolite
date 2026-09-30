require "rails_helper"

RSpec.describe Inventory do
  it "recusa quantidade negativa na validação" do
    inventory = build(:inventory, quantity: -1)

    expect(inventory).not_to be_valid
    expect(inventory.errors[:quantity]).to include("deve ser maior ou igual a 0")
  end

  it "recusa quantidade fracionária" do
    expect(build(:inventory, quantity: 1.5)).not_to be_valid
  end

  # update_column pula validações e callbacks: é como um SQL direto. Mesmo assim o
  # banco recusa, graças à check constraint.
  it "é protegido pela check constraint do banco" do
    inventory = create(:product).inventory

    expect { inventory.update_column(:quantity, -1) }
      .to raise_error(ActiveRecord::StatementInvalid, /inventories_quantity_non_negative/)
  end

  it "permite só um estoque por produto (índice único)" do
    product = create(:product)
    second = described_class.new(product:, quantity: 1)

    expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe ".withdraw" do
    let(:mug) { create(:product, stock: 5) }
    let(:pen) { create(:product, stock: 1) }

    it "dá baixa em todos os produtos de uma vez" do
      expect(described_class.withdraw(mug.id => 2, pen.id => 1)).to be(true)

      expect([ mug.inventory.reload.quantity, pen.inventory.reload.quantity ]).to eq([ 3, 0 ])
    end

    it "tudo ou nada: se falta estoque de um produto, não baixa nenhum" do
      expect(described_class.withdraw(mug.id => 2, pen.id => 2)).to be(false)

      expect([ mug.inventory.reload.quantity, pen.inventory.reload.quantity ]).to eq([ 5, 1 ])
    end

    it "recusa produto sem linha de estoque" do
      mug.inventory.delete

      expect(described_class.withdraw(mug.id => 1, pen.id => 1)).to be(false)
      expect(pen.inventory.reload.quantity).to eq(1)
    end

    # A ordem da trava é o que impede deadlock entre duas compras dos mesmos produtos.
    it "trava as linhas com FOR UPDATE, em ordem de product_id" do
      ids = { pen.id => 1, mug.id => 1 }
      sql = []
      capture = ->(*, payload) { sql << payload[:sql] if payload[:sql].start_with?("SELECT \"inventories\"") }
      ActiveSupport::Notifications.subscribed(capture, "sql.active_record") do
        described_class.withdraw(ids)
      end

      expect(sql.first).to match(/ORDER BY "inventories"\."product_id" ASC .*FOR UPDATE/)
    end
  end
end
