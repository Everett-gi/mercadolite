require "rails_helper"

RSpec.describe ProductsHelper do
  describe "#price_tag" do
    it "formata centavos em reais no padrão brasileiro" do
      expect(helper.price_tag(4_990)).to eq("R$ 49,90")
      expect(helper.price_tag(123_456)).to eq("R$ 1.234,56")
    end
  end

  describe "#sort_options" do
    # As opções da tela precisam bater com a lista fechada do ProductSearch.
    it "oferece exatamente as ordenações aceitas" do
      expect(helper.sort_options.map(&:last)).to match_array(ProductSearch::SORTS.keys)
    end
  end
end
