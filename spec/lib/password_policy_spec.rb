require "rails_helper"

RSpec.describe PasswordPolicy do
  describe ".weakness" do
    it "aceita uma frase com palavras aleatórias" do
      expect(described_class.weakness("trem azul noturno 42")).to be_nil
    end

    [ "aaaaaaaaaaaaaaaa", "abababababababab", "1231231231231231", "abcdabcdabcdabcd" ].each do |password|
      it "recusa #{password.inspect} (menos de #{PasswordPolicy::MIN_DISTINCT_CHARS} caracteres diferentes)" do
        expect(described_class.weakness(password)).to eq(:repetitive)
      end
    end

    it "aceita 5 caracteres diferentes, o mínimo" do
      expect(described_class.weakness("abcdeabcdeabcde")).to be_nil
    end

    it "recusa o nome da loja, em qualquer caixa" do
      expect(described_class.weakness("Minha MercadoLite 2026")).to eq(:service_name)
    end

    it "recusa senha que contém a parte do e-mail antes do @" do
      expect(described_class.weakness("joana.silva-cavalo", email: "Joana.Silva@exemplo.com")).to eq(:email)
    end

    it "ignora partes do e-mail curtas demais (aparecem por acaso em palavras)" do
      expect(described_class.weakness("banana nanica madura", email: "ana@exemplo.com")).to be_nil
    end

    it "funciona sem e-mail e com senha nil" do
      expect(described_class.weakness("trem azul noturno 42", email: nil)).to be_nil
      expect(described_class.weakness(nil)).to eq(:repetitive)
    end
  end
end
