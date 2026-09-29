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
end
