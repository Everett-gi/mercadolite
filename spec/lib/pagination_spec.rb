require "rails_helper"

RSpec.describe Pagination do
  def build(requested_page:, total_count:, per_page: 10)
    described_class.build(requested_page:, per_page:, total_count:)
  end

  it "calcula offset e vizinhas numa página do meio" do
    pagination = build(requested_page: 2, total_count: 35)

    expect(pagination).to have_attributes(
      page: 2, total_pages: 4, offset: 10, previous_page: 1, next_page: 3
    )
  end

  it "arredonda o total de páginas para cima" do
    expect(build(requested_page: 1, total_count: 31).total_pages).to eq(4)
    expect(build(requested_page: 1, total_count: 30).total_pages).to eq(3)
  end

  it "tem pelo menos uma página, mesmo sem itens" do
    pagination = build(requested_page: 1, total_count: 0)

    expect(pagination).to have_attributes(page: 1, total_pages: 1, offset: 0,
                                          previous_page: nil, next_page: nil)
  end

  it "prende uma página grande demais na última (nada de OFFSET gigante)" do
    pagination = build(requested_page: 999_999_999, total_count: 35)

    expect(pagination.page).to eq(4)
    expect(pagination.offset).to eq(30)
  end

  [ nil, 0, -5 ].each do |requested|
    it "trata a página #{requested.inspect} como a primeira" do
      expect(build(requested_page: requested, total_count: 35).page).to eq(1)
    end
  end

  it "é imutável" do
    pagination = build(requested_page: 1, total_count: 35)

    expect(pagination).to be_frozen
    expect { pagination.instance_variable_set(:@page, 3) }.to raise_error(FrozenError)
  end

  it "recusa per_page zero ou negativo" do
    expect { build(requested_page: 1, total_count: 5, per_page: 0) }
      .to raise_error(ArgumentError, /per_page/)
  end

  it "recusa total negativo" do
    expect { build(requested_page: 1, total_count: -1) }
      .to raise_error(ArgumentError, /total_count/)
  end
end
