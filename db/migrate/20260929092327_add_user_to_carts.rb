# O carrinho ganha um dono opcional. Visitante: user_id nulo, e o id do carrinho fica na
# sessão. Logado: o carrinho pertence ao usuário e é achado por ele, não pela sessão.
class AddUserToCarts < ActiveRecord::Migration[8.1]
  def change
    # on_delete: :cascade — excluir a conta apaga o carrinho (e, em cascata, os itens).
    # index unique — no máximo UM carrinho por usuário. O índice único do PostgreSQL aceita
    # vários NULL, então os carrinhos de visitante não conflitam entre si.
    add_reference :carts, :user, foreign_key: { on_delete: :cascade }, index: { unique: true }
  end
end
