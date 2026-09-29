FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "comprador#{n}@exemplo.test" }
    password { "trem azul noturno 42" }
    terms_of_service { "1" }
    # Confirmada por padrão: a maioria dos testes quer uma conta que já pode entrar.
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end
