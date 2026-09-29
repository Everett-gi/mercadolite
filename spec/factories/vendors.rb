# Fábricas: "moldes" de objetos válidos para os testes. create(:vendor) grava um
# vendedor no banco; build(:vendor) só cria o objeto em memória.
FactoryBot.define do
  factory :vendor do
    # sequence gera um valor diferente a cada chamada: "Vendedor 1", "Vendedor 2"...
    sequence(:name) { |n| "Vendedor #{n}" }
    description { "Um vendedor de teste." }
  end
end
