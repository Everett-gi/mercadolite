FactoryBot.define do
  factory :product do
    vendor
    sequence(:name) { |n| "Produto #{n}" }
    description { "Descrição de teste." }
    price_cents { 1_000 }

    # Atributo "transient": não existe no modelo, só configura a fábrica.
    # create(:product, stock: 5) cria o produto já com 5 unidades em estoque.
    transient do
      stock { 0 }
    end

    after(:create) do |product, context|
      product.inventory.update!(quantity: context.stock) if context.stock.positive?
    end

    trait :inactive do
      active { false }
    end

    trait :with_image do
      after(:build) do |product|
        product.images.attach(
          io: Rails.root.join("spec/fixtures/files/produto.png").open,
          filename: "produto.png"
        )
      end
    end
  end
end
