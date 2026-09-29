FactoryBot.define do
  # O estoque normalmente nasce junto com o produto (Product#build_default_inventory);
  # esta fábrica serve para testar o modelo Inventory isoladamente.
  factory :inventory do
    product
    quantity { 0 }
  end
end
