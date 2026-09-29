# Produtos do catálogo. O preço é guardado em CENTAVOS, como inteiro: dinheiro nunca
# vai para float (0.1 + 0.2 != 0.3 em ponto flutuante binário).
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :vendor, null: false, foreign_key: true
      t.string :name, null: false, limit: 120
      t.text :description, null: false, default: ""
      t.integer :price_cents, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    # A regra também mora no banco: nenhum caminho (console, SQL, bug) grava preço
    # zero, negativo ou absurdo. Limite: R$ 1.000.000,00 = 100.000.000 centavos.
    add_check_constraint :products, "price_cents > 0 AND price_cents <= 100000000",
      name: "products_price_cents_range"

    # A vitrine lista os produtos ativos, dos mais novos para os mais antigos.
    add_index :products, [ :active, :created_at ]
  end
end
