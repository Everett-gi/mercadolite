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

  describe ".guest" do
    it "traz só carrinhos sem dono" do
      guest = create(:cart)
      create(:cart, user: create(:user))

      expect(described_class.guest).to contain_exactly(guest)
    end
  end

  it "o banco não deixa uma conta ter dois carrinhos" do
    user = create(:user)
    create(:cart, user:)

    expect { described_class.create!(user:) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe ".claim" do
    let(:user) { create(:user) }
    let(:mug) { create(:product, stock: 20) }
    let(:guest) { create(:cart).tap { |cart| cart.add(mug, 3) } }

    it "sem carrinho de visitante, devolve o da conta (ou nil)" do
      expect(described_class.claim(nil, user)).to be_nil
    end

    it "se a conta não tem carrinho, o de visitante passa a ser dela" do
      claimed = described_class.claim(guest, user)

      expect(claimed).to eq(guest)
      expect(guest.reload.user).to eq(user)
    end

    it "se a conta já tem carrinho, soma os itens nele e apaga o de visitante" do
      own = create(:cart, user:)
      own.add(mug, 2)
      teapot = create(:product, stock: 5)
      guest.add(teapot, 1)

      claimed = described_class.claim(guest, user)

      expect(claimed).to eq(own)
      expect(own.items.pluck(:product_id, :quantity)).to contain_exactly([ mug.id, 5 ], [ teapot.id, 1 ])
      expect(described_class.exists?(guest.id)).to be(false)
    end
  end

  describe "#merge_item" do
    let(:cart) { create(:cart) }

    it "limita a soma a #{CartItem::MAX_QUANTITY} unidades por linha" do
      mug = create(:product, stock: 50)
      cart.add(mug, 8)

      expect(cart.merge_item(mug, 5)).to be(true)
      expect(cart.items.sole.quantity).to eq(CartItem::MAX_QUANTITY)
    end

    it "limita a soma ao estoque atual" do
      mug = create(:product, stock: 4)
      cart.add(mug, 3)

      cart.merge_item(mug, 3)

      expect(cart.items.sole.quantity).to eq(4)
    end

    it "descarta produto fora de venda ou sem estoque" do
      expect(cart.merge_item(create(:product, :inactive, stock: 5), 1)).to be(false)
      expect(cart.merge_item(create(:product, stock: 0), 1)).to be(false)
      expect(cart.items).to be_empty
    end
  end
end
