require "rails_helper"

RSpec.describe Brl do
  describe ".parse_cents" do
    # Tabela de casos: [texto digitado, centavos esperados]
    {
      "49,90" => 4_990,
      "49.90" => 4_990,
      "49,9" => 4_990,
      "50" => 5_000,
      "0,05" => 5,
      " 12,5 " => 1_250,
      "0" => 0,
      "9999999,99" => 999_999_999,
      "08" => 800 # zero à esquerda não vira octal
    }.each do |text, expected|
      it "converte #{text.inspect} em #{expected} centavos" do
        expect(described_class.parse_cents(text)).to eq(expected)
      end
    end

    [
      nil, "", "   ", "abc", "-10", "10,", ",50", "10,999", "1.234,56", "1.234",
      "R$ 10", "10 000", "1e3", "12345678", "10;DROP TABLE products"
    ].each do |text|
      it "recusa #{text.inspect}" do
        expect(described_class.parse_cents(text)).to be_nil
      end
    end
  end

  describe ".from_cents" do
    it "devolve BigDecimal exato, sem erro de ponto flutuante" do
      value = described_class.from_cents(4_990)

      expect(value).to be_a(BigDecimal)
      expect(value).to eq(BigDecimal("49.9"))
    end

    it "soma sem o erro clássico do float (0,10 + 0,20 = 0,30)" do
      sum = described_class.from_cents(10) + described_class.from_cents(20)

      expect(sum).to eq(BigDecimal("0.3"))
      expect(0.1 + 0.2).not_to eq(0.3) # o motivo de não usarmos float
    end
  end
end
