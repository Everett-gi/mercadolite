require "rails_helper"

RSpec.describe OrderPolicy do
  let(:owner) { create(:user) }
  let(:stranger) { create(:user) }
  let(:order) { create(:order, user: owner) }

  it "o dono pode ver e pagar o próprio pedido" do
    policy = described_class.new(owner, order)

    expect(policy.show?).to be(true)
    expect(policy.create?).to be(true)
  end

  it "outra pessoa não pode ver nem pagar o pedido" do
    policy = described_class.new(stranger, order)

    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
  end

  it "sem login, nada" do
    policy = described_class.new(nil, order)

    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
  end

  it "o que não foi liberado é proibido (ninguém edita nem apaga pedido por aqui)" do
    policy = described_class.new(owner, order)

    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  describe "Scope" do
    it "cada um enxerga só os próprios pedidos" do
      mine = create(:order, user: owner)
      create(:order, user: stranger)

      expect(OrderPolicy::Scope.new(owner, Order).resolve).to contain_exactly(mine)
      expect(OrderPolicy::Scope.new(nil, Order).resolve).to be_empty
    end
  end
end
