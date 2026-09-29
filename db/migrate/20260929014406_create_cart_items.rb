# Itens do carrinho: QUAL produto e QUANTAS unidades. De propósito, não há coluna de preço:
# o preço é sempre lido do produto no banco, nunca de algo que o navegador enviou.
class CreateCartItems < ActiveRecord::Migration[8.1]
  def change
    create_table :cart_items do |t|
      # on_delete: :cascade — apagar um carrinho apaga os itens dele NO PRÓPRIO BANCO.
      # É o que permite ao job de limpeza apagar milhares de carrinhos com um DELETE só.
      # index: false — o índice composto [cart_id, product_id] lá embaixo já atende as
      # buscas só por cart_id (é o "prefixo à esquerda" dele); um segundo seria redundante.
      t.references :cart, null: false, foreign_key: { on_delete: :cascade }, index: false
      # Um produto com itens em carrinhos não pode ser apagado (use "active: false").
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false

      t.timestamps
    end

    # Uma linha por produto em cada carrinho: adicionar de novo SOMA à linha existente.
    add_index :cart_items, [ :cart_id, :product_id ], unique: true

    # De 1 a 10 unidades por item (CartItem::MAX_QUANTITY), garantido também pelo banco.
    add_check_constraint :cart_items, "quantity BETWEEN 1 AND 10", name: "cart_items_quantity_range"
  end
end
