FactoryBot.define do
  factory :cart_item do
    cart
    # Um produto GRAVADO e com estoque, para o item nascer válido. strategy: :create vale
    # até no build(:cart_item): o estoque só existe depois que o produto é salvo.
    product { association :product, strategy: :create, stock: 10 }
    quantity { 1 }
  end
end
