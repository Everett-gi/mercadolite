# Pedidos. Nascem do carrinho, com o preço de cada item "congelado" (em order_items): mudar o
# preço do produto depois não muda um pedido já feito.
class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      # Todo pedido nasce com dono (validação no modelo). A coluna aceita NULL só para um caso:
      # quando o dono exclui a conta (LGPD), o pedido fica, mas sem ligação com a pessoa
      # (registro contábil sem dado pessoal). Por isso on_delete: :nullify.
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :status, null: false, default: "pending"
      t.integer :total_cents, null: false
      t.string :currency, null: false, default: "brl"

      # Ids do lado do Stripe: a sessão de pagamento (Checkout) e o pagamento em si.
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.datetime :paid_at
      t.datetime :canceled_at

      t.timestamps
    end

    add_index :orders, :stripe_checkout_session_id, unique: true
    add_index :orders, :stripe_payment_intent_id, unique: true

    add_check_constraint :orders, "status IN ('pending', 'paid', 'shipped', 'canceled')", name: "orders_status_valid"
    add_check_constraint :orders, "total_cents > 0", name: "orders_total_positive"
    add_check_constraint :orders, "currency = 'brl'", name: "orders_currency_brl"
    # Pedido pago precisa da data do pagamento.
    add_check_constraint :orders, "status NOT IN ('paid', 'shipped') OR paid_at IS NOT NULL", name: "orders_paid_has_date"
  end
end
