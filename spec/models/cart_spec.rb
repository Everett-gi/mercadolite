require "rails_helper"

RSpec.describe Cart do
  let(:cart) { create(:cart) }
  let(:caneca) { create(:product, name: "Caneca", price_cents: 4_990, stock: 10) }
  let(:bule) { create(:product, name: "Bule", price_cents: 12_950, stock: 3) }

  describe "#add" do
    it "cria a linha do produto" do
      item = cart.add(caneca, 2)

      expect(item).to be_persisted
      expect(cart.items.count).to eq(1)
      expect(item.quantity).to eq(2)
    end

    it "soma à linha existente em vez de duplicar" do
      cart.add(caneca, 2)
      item = cart.add(caneca, 3)

      expect(cart.items.count).to eq(1)
      expect(item.reload.quantity).to eq(5)
    end

    it "devolve o item com erros quando a soma passa do estoque" do
      cart.add(bule, 2)
      item = cart.add(bule, 2)

      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to be_present
      expect(cart.items.first.reload.quantity).to eq(2) # nada mudou no banco
    end
  end

  describe "#subtotal_cents e #items_count" do
    before do
      cart.add(caneca, 2)
      cart.add(bule, 1)
    end

    it "somam as linhas com o preço atual do banco" do
      expect(cart.subtotal_cents).to eq((4_990 * 2) + 12_950)
      expect(cart.items_count).to eq(3)

      caneca.update!(price_cents: 1_000) # o preço mudou depois de ir para o carrinho
      expect(cart.subtotal_cents).to eq((1_000 * 2) + 12_950)
    end

    it "deixam de fora do subtotal o que não pode ser comprado agora" do
      bule.update!(active: false)

      expect(cart.subtotal_cents).to eq(4_990 * 2)
    end
  end

  it "#lines mantém a ordem em que os produtos foram adicionados" do
    cart.add(bule, 1)
    cart.add(caneca, 1)

    expect(cart.lines.map { |line| line.product.name }).to eq(%w[Bule Caneca])
  end

  it "apagar o carrinho apaga os itens" do
    cart.add(caneca, 1)

    expect { cart.destroy }.to change(CartItem, :count).by(-1)
  end

  describe ".abandoned" do
    it "traz só os carrinhos parados há mais de #{Cart::ABANDONED_AFTER.inspect}" do
      old = create(:cart, updated_at: (Cart::ABANDONED_AFTER + 1.day).ago)
      create(:cart, updated_at: (Cart::ABANDONED_AFTER - 1.day).ago)

      expect(described_class.abandoned).to contain_exactly(old)
    end
  end
end
