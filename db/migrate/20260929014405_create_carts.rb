# Carrinho de compras. Nesta fase ele é anônimo: quem o encontra é a SESSÃO do navegador,
# que guarda o id do carrinho num cookie cifrado. Na fase 3, ele ganha um dono (usuário).
class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      t.timestamps
    end

    # O job de limpeza procura carrinhos parados há muito tempo por updated_at.
    add_index :carts, :updated_at
  end
end
