require "rails_helper"

RSpec.describe ProductSearch do
  describe "conversão de tipos (atributos tipados)" do
    it "converte as strings da URL para os tipos declarados" do
      search = described_class.new(vendor_id: "7", in_stock: "1", page: "3")

      expect(search).to have_attributes(vendor_id: 7, in_stock: true, page: 3)
    end

    # Conversão não é validação: o tipo :integer usa to_i por baixo.
    it "converte de forma tolerante (por isso também validamos)" do
      expect(described_class.new(vendor_id: "abc").vendor_id).to eq(0)
      expect(described_class.new(vendor_id: "12abc").vendor_id).to eq(12)
    end

    it "usa os valores padrão quando o parâmetro não vem" do
      expect(described_class.new).to have_attributes(sort: "recentes", page: 1, in_stock: false)
    end
  end

  describe "validação" do
    it "limita o tamanho da busca" do
      search = described_class.new(q: "a" * (ProductSearch::MAX_QUERY_LENGTH + 1))

      expect(search).not_to be_valid
      expect(search.errors[:q]).to be_present
    end

    [ "abc", "0", "-1" ].each do |invalid|
      it "recusa vendedor #{invalid.inspect}" do
        search = described_class.new(vendor_id: invalid)

        expect(search).not_to be_valid
        expect(search.errors[:vendor_id]).to include("deve ser maior que 0")
      end
    end

    it "só aceita ordenações da lista fechada" do
      search = described_class.new(sort: "price_cents; DROP TABLE products")

      expect(search).not_to be_valid
      expect(search.errors[:sort]).to include("não está incluído na lista")
    end

    it "recusa preço em formato inválido" do
      search = described_class.new(min_price: "1.234,56")

      expect(search).not_to be_valid
      expect(search.errors[:min_price]).to include("deve ser um valor como 49,90")
    end

    it "recusa preço mínimo maior que o máximo" do
      search = described_class.new(min_price: "50", max_price: "10")

      expect(search).not_to be_valid
      expect(search.errors[:max_price]).to include("não pode ser menor que o preço mínimo")
    end

    it "não devolve resultados quando é inválida" do
      create(:product)

      expect(described_class.new(sort: "hack").results).to be_empty
    end
  end

  describe "#results" do
    let(:vendor) { create(:vendor) }
    let!(:caneca) { create(:product, vendor:, name: "Caneca", price_cents: 4_990, stock: 3) }
    let!(:bule) { create(:product, vendor:, name: "Bule", price_cents: 12_950, stock: 0) }
    let!(:caderno) { create(:product, name: "Caderno", price_cents: 4_200, stock: 9) }

    before { create(:product, :inactive, name: "Caneca antiga", vendor:) }

    it "lista só produtos ativos" do
      expect(described_class.new.results).to contain_exactly(caneca, bule, caderno)
    end

    it "filtra por texto" do
      expect(described_class.new(q: "  caneca ").results).to contain_exactly(caneca)
    end

    it "filtra por vendedor" do
      expect(described_class.new(vendor_id: vendor.id.to_s).results).to contain_exactly(caneca, bule)
    end

    it "filtra por faixa de preço (em reais, inclusive nas pontas)" do
      results = described_class.new(min_price: "42", max_price: "49,90").results

      expect(results).to contain_exactly(caneca, caderno)
    end

    it "filtra só os que têm estoque" do
      expect(described_class.new(in_stock: "1").results).to contain_exactly(caneca, caderno)
    end

    it "ordena pelo menor preço" do
      expect(described_class.new(sort: "menor_preco").results.to_a).to eq([ caderno, caneca, bule ])
    end

    it "ordena pelo nome" do
      expect(described_class.new(sort: "nome").results.map(&:name)).to eq(%w[Bule Caderno Caneca])
    end
  end

  describe "#to_params" do
    it "devolve só os filtros preenchidos, já normalizados" do
      search = described_class.new(q: "café", vendor_id: "3", in_stock: "1", min_price: "",
                                   sort: "nome", page: "2")

      expect(search.to_params).to eq(q: "café", vendor_id: 3, in_stock: "1", sort: "nome")
    end
  end

  describe "#filtered?" do
    it "é falso quando só há ordenação" do
      expect(described_class.new(sort: "nome")).not_to be_filtered
    end

    it "é verdadeiro quando há algum filtro" do
      expect(described_class.new(q: "x")).to be_filtered
    end
  end
end
