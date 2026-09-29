require "rails_helper"

RSpec.describe Quantity do
  describe ".parse" do
    {
      "1" => 1,
      "10" => 10,
      " 3 " => 3,
      "08" => 8, # zero à esquerda não vira octal
      7 => 7     # aceita Integer também (ex.: valor padrão do formulário)
    }.each do |input, expected|
      it "aceita #{input.inspect} como #{expected}" do
        expect(described_class.parse(input, max: 10)).to eq(expected)
      end
    end

    [
      nil, "", "  ", "0", "11", "-1", "+2", "2.5", "2,5", "abc", "2abc", "1e2",
      "1 0", "0x1", "１", "9999", "3; DROP TABLE carts"
    ].each do |input|
      it "recusa #{input.inspect}" do
        expect(described_class.parse(input, max: 10)).to be_nil
      end
    end

    it "respeita o máximo informado" do
      expect(described_class.parse("4", max: 3)).to be_nil
      expect(described_class.parse("3", max: 3)).to eq(3)
    end

    it "recusa um máximo que não seja positivo" do
      expect { described_class.parse("1", max: 0) }.to raise_error(ArgumentError, /max/)
    end
  end
end
