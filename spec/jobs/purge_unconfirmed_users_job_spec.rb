require "rails_helper"

RSpec.describe PurgeUnconfirmedUsersJob do
  it "apaga contas não confirmadas há mais de 7 dias, com o carrinho delas" do
    old = create(:user, :unconfirmed, created_at: 8.days.ago)
    cart = create(:cart, user: old)
    recent = create(:user, :unconfirmed, created_at: 1.day.ago)
    confirmed = create(:user, created_at: 30.days.ago)

    expect(described_class.perform_now).to eq(1)

    expect(User.all).to contain_exactly(recent, confirmed)
    expect(Cart.exists?(cart.id)).to be(false) # ON DELETE CASCADE no banco
  end
end
