require "rails_helper"

RSpec.describe Vendor do
  it "é válido com os atributos da fábrica" do
    expect(build(:vendor)).to be_valid
  end

  it "exige nome" do
    vendor = build(:vendor, name: "")

    expect(vendor).not_to be_valid
    expect(vendor.errors[:name]).to include("não pode ficar em branco")
  end

  it "limita o tamanho do nome" do
    expect(build(:vendor, name: "x" * (Vendor::MAX_NAME_LENGTH + 1))).not_to be_valid
  end

  it "normaliza espaços do nome" do
    expect(build(:vendor, name: "  Loja   do  Zé ").name).to eq("Loja do Zé")
  end

  describe "nome único sem diferenciar maiúsculas" do
    before { create(:vendor, name: "Loja X") }

    it "é barrado pela validação do modelo" do
      duplicate = build(:vendor, name: "loja x")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("já está em uso")
    end

    # A validação do modelo tem uma janela de corrida (dois pedidos simultâneos passam
    # juntos pelo SELECT). O índice único no banco fecha essa janela.
    it "é barrado pelo índice único do banco, mesmo sem validação" do
      duplicate = build(:vendor, name: "LOJA X")

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it "não pode ser apagado enquanto tiver produtos" do
    vendor = create(:vendor)
    create(:product, vendor:)

    expect(vendor.destroy).to be(false)
    expect(vendor.errors[:base]).to include("Não é possível excluir o registro pois existem produtos dependentes")
    expect(Vendor.exists?(vendor.id)).to be(true)
  end
end
