require "rails_helper"
require "vips" # a ruby-vips é require: false no Gemfile (veja o comentário lá)

RSpec.describe Product do
  let(:fixtures) { Rails.root.join("spec/fixtures/files") }

  it "é válido com os atributos da fábrica" do
    expect(build(:product)).to be_valid
  end

  describe "preço" do
    it "exige preço positivo" do
      product = build(:product, price_cents: 0)

      expect(product).not_to be_valid
      expect(product.errors[:price_cents]).to include("deve ser maior que 0")
    end

    it "recusa preço acima do limite" do
      expect(build(:product, price_cents: Product::MAX_PRICE_CENTS + 1)).not_to be_valid
    end

    it "é protegido pela check constraint do banco" do
      product = create(:product)

      expect { product.update_column(:price_cents, -100) }
        .to raise_error(ActiveRecord::StatementInvalid, /products_price_cents_range/)
    end

    it "é exposto em reais como BigDecimal" do
      expect(build(:product, price_cents: 4_990).price).to eq(BigDecimal("49.90"))
    end
  end

  it "exige nome e normaliza espaços" do
    expect(build(:product, name: " ")).not_to be_valid
    expect(build(:product, name: "  Caneca   azul ").name).to eq("Caneca azul")
  end

  describe "estoque" do
    it "nasce com um registro de estoque zerado" do
      product = create(:product)

      expect(product.inventory).to be_persisted
      expect(product.inventory.quantity).to eq(0)
      expect(product).not_to be_in_stock
    end

    it "trata estoque ainda não criado (produto não gravado) como zero" do
      product = build(:product)

      expect(product.inventory).to be_nil
      expect(product.stock_quantity).to eq(0)
      expect(product).not_to be_in_stock
    end

    it "está em estoque quando a quantidade é positiva" do
      expect(create(:product, stock: 3)).to be_in_stock
    end

    it "apaga o estoque junto com o produto" do
      product = create(:product)

      expect { product.destroy }.to change(Inventory, :count).by(-1)
    end
  end

  describe "imagens" do
    def attach(product, filename, content_type: nil)
      product.images.attach(io: fixtures.join(filename).open, filename:, content_type:)
    end

    it "aceita PNG" do
      product = build(:product)
      attach(product, "produto.png")

      expect(product).to be_valid
    end

    # SVG pode conter <script>: servido pelo nosso domínio, viraria XSS.
    it "recusa SVG" do
      product = build(:product)
      attach(product, "malicioso.svg")

      expect(product).not_to be_valid
      expect(product.errors.full_messages.join).to include("malicioso.svg não é JPEG, PNG nem WebP")
    end

    # Um executável ou um HTML têm "assinatura" (magic number) nos primeiros bytes, e
    # o Active Storage (gem Marcel) descobre o tipo real mesmo com o nome trocado.
    it "descobre o tipo real pelos bytes quando há assinatura (SVG renomeado)" do
      product = build(:product)
      product.images.attach(io: fixtures.join("malicioso.svg").open,
                            filename: "inocente.png", content_type: "image/png")

      expect(product.images.first.blob.content_type).to eq("image/svg+xml")
      expect(product).not_to be_valid
    end

    # LIMITAÇÃO CONHECIDA: texto puro não tem assinatura, então a Marcel confia no nome
    # e no tipo declarado, e o arquivo passa como PNG. Hoje não há upload pela web
    # (o cadastro chega na fase 5) e o cabeçalho nosniff impede o navegador de
    # interpretar o arquivo como outra coisa. "pending" roda o teste esperando a falha:
    # quando a fase 5 validar os bytes com a libvips, o RSpec avisa que ele passou.
    it "recusa um arquivo de texto disfarçado de PNG" do
      pending "fase 5: conferir se os bytes são mesmo uma imagem (libvips)"
      product = build(:product)
      attach(product, "falso.png", content_type: "image/png")

      expect(product).not_to be_valid
    end

    it "recusa imagem grande demais" do
      stub_const("Product::MAX_IMAGE_BYTES", 100) # o PNG de teste tem ~290 bytes
      product = build(:product)
      attach(product, "produto.png")

      expect(product).not_to be_valid
      expect(product.errors.full_messages.join).to include("passa de")
    end

    # Gera a miniatura DE VERDADE (libvips via gem ruby-vips), em vez de só conferir a URL.
    # Protege contra uma atualização de gem que tire a ruby-vips do bundle: sem este teste,
    # o CI passaria e as imagens só quebrariam em produção.
    it "gera a miniatura com a libvips" do
      product = create(:product, :with_image)

      variant = product.images.first.variant(:thumb).processed
      thumbnail = Vips::Image.new_from_buffer(variant.download, "")

      expect(variant.key).to be_present
      expect([ thumbnail.width, thumbnail.height ].max).to be <= 400
    end

    it "limita a quantidade de imagens" do
      product = build(:product)
      (Product::MAX_IMAGES + 1).times { attach(product, "produto.png") }

      expect(product).not_to be_valid
      expect(product.errors.full_messages.join).to include("no máximo #{Product::MAX_IMAGES}")
    end
  end

  describe ".matching" do
    let!(:caneca) { create(:product, name: "Caneca de Cerâmica", description: "Azul") }
    let!(:cafe) { create(:product, name: "Café em grãos", description: "Torra média") }
    let!(:desconto) { create(:product, name: "Cupom 100% off", description: "promo_relampago") }

    it "ignora maiúsculas e acentos" do
      expect(described_class.matching("CERAMICA")).to contain_exactly(caneca)
      expect(described_class.matching("cafe")).to contain_exactly(cafe)
    end

    it "busca também na descrição" do
      expect(described_class.matching("torra")).to contain_exactly(cafe)
    end

    # Sem sanitize_sql_like, "%" viraria o curinga "qualquer coisa" (acharia todos) e
    # "_" o curinga "um caractere qualquer" ("C_neca" acharia "Caneca").
    it "trata % e _ digitados como texto, não como curinga" do
      expect(described_class.matching("%")).to contain_exactly(desconto)
      expect(described_class.matching("C_neca")).to be_empty
      expect(described_class.matching("promo_rel")).to contain_exactly(desconto)
    end

    it "trata tentativa de SQL injection como texto comum" do
      expect(described_class.matching("' OR 1=1 --")).to be_empty
      expect(described_class.count).to eq(3)
    end
  end

  describe "escopos" do
    it ".active exclui produtos inativos" do
      active = create(:product)
      create(:product, :inactive)

      expect(described_class.active).to contain_exactly(active)
    end

    it ".in_stock traz só quem tem quantidade positiva" do
      with_stock = create(:product, stock: 2)
      create(:product, stock: 0)

      expect(described_class.in_stock).to contain_exactly(with_stock)
    end
  end
end
