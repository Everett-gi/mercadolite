# Estoque de um produto (relação 1:1). A quantidade nunca é negativa: a validação dá a
# mensagem amigável, e a check constraint do banco é a garantia final.
class Inventory < ApplicationRecord
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Dá baixa, de uma vez, no estoque de vários produtos: ou baixa TUDO, ou nada.
  #
  # As linhas de estoque são lidas com SELECT ... FOR UPDATE: outra transação que queira
  # baixar os mesmos produtos espera esta terminar e então lê a quantidade já atualizada.
  # A trava acontece sempre em ordem crescente de product_id: duas transações que precisam
  # dos mesmos produtos travam na mesma ordem e nunca ficam esperando uma pela outra em
  # círculo (deadlock).
  #
  # @param quantities [Hash{Integer => Integer}] product_id => quantidade a baixar
  # @return [Boolean] true se deu baixa; false se faltou estoque (e nada mudou)
  def self.withdraw(quantities)
    transaction do
      stock = where(product_id: quantities.keys).order(:product_id).lock.to_a
      enough = stock.size == quantities.size &&
               stock.all? { |inventory| inventory.quantity >= quantities.fetch(inventory.product_id) }
      stock.each { |inventory| inventory.update!(quantity: inventory.quantity - quantities.fetch(inventory.product_id)) } if enough
      enough
    end
  end
end
