# Estoque de um produto (relação 1:1). A quantidade nunca é negativa: a validação dá a
# mensagem amigável, e a check constraint do banco é a garantia final.
class Inventory < ApplicationRecord
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
