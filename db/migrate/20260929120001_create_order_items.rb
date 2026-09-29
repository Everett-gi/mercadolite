# Itens do pedido: uma FOTO do produto no momento da compra (nome e preço copiados). O
# product_id fica para referência, mas o que vale para o pedido é o que está aqui.
class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }, index: false
      # Sem cascade: o banco não deixa apagar um produto que já foi vendido (desative-o).
      t.references :product, null: false, foreign_key: true
      t.string :product_name, null: false, limit: 120
      t.integer :unit_price_cents, null: false
      t.integer :quantity, null: false

      t.timestamps
    end

    # Uma linha por produto em cada pedido (o índice também serve às buscas por order_id).
    add_index :order_items, [ :order_id, :product_id ], unique: true

    add_check_constraint :order_items, "unit_price_cents > 0 AND unit_price_cents <= 100000000", name: "order_items_price_range"
    add_check_constraint :order_items, "quantity BETWEEN 1 AND 10", name: "order_items_quantity_range"
  end
end
