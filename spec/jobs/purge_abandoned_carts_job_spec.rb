require "rails_helper"

RSpec.describe PurgeAbandonedCartsJob do
  it "apaga os carrinhos abandonados e os itens deles, e mantém os recentes" do
    product = create(:product, stock: 10)
    old = create(:cart)
    old.add(product, 1)
    old.update_column(:updated_at, (Cart::ABANDONED_AFTER + 1.day).ago)
    recent = create(:cart)
    recent.add(product, 1)

    deleted = described_class.perform_now

    expect(deleted).to eq(1)
    expect(Cart.all).to contain_exactly(recent)
    expect(CartItem.where(cart_id: old.id)).to be_empty # ON DELETE CASCADE no banco
  end

  it "não faz nada quando não há carrinhos abandonados" do
    create(:cart)

    expect(described_class.perform_now).to eq(0)
  end
end
