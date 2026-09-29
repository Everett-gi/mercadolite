# Estoque: uma linha por produto, separada da tabela de produtos. Na fase 4, a baixa de
# estoque vai travar (SELECT ... FOR UPDATE) só esta linha, sem bloquear quem estiver
# editando o nome ou a descrição do produto ao mesmo tempo.
class CreateInventories < ActiveRecord::Migration[8.1]
  def change
    create_table :inventories do |t|
      # index unique: no máximo UM estoque por produto (relação 1:1 garantida no banco).
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.integer :quantity, null: false, default: 0

      t.timestamps
    end

    # Estoque nunca fica negativo, nem sob concorrência: o banco recusa a gravação.
    add_check_constraint :inventories, "quantity >= 0", name: "inventories_quantity_non_negative"
  end
end
