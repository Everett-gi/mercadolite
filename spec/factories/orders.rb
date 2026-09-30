FactoryBot.define do
  factory :order do
    user
    status { "pending" }
    sequence(:stripe_checkout_session_id) { |n| "cs_test_#{n}" }

    # Um item por padrão (o pedido precisa de pelo menos um), e o total calculado dele.
    transient do
      product { association :product, strategy: :create, price_cents: 4_990, stock: 10 }
      quantity { 2 }
    end

    after(:build) do |order, context|
      if order.items.empty?
        order.items.build(product: context.product, product_name: context.product.name,
                          unit_price_cents: context.product.price_cents, quantity: context.quantity)
      end
      order.total_cents ||= order.items.sum(&:line_total_cents)
    end

    trait :paid do
      status { "paid" }
      paid_at { Time.current }
      sequence(:stripe_payment_intent_id) { |n| "pi_test_#{n}" }
    end

    # Pago, mas sem estoque: aguardando o estorno.
    trait :refunding do
      paid
      status { "refunding" }
    end
  end
end
