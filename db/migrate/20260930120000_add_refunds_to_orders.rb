# Estorno: quando o estoque acaba entre o checkout e a confirmação do pagamento, o pedido não
# pode ser atendido e o dinheiro volta ao comprador.
#
#   pending ──(pago, com estoque)──► paid
#      └────(pago, SEM estoque)────► refunding ──(Stripe aceitou o estorno)──► refunded
class AddRefundsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :refunded_at, :datetime
    # O id do estorno no Stripe (re_...).
    add_column :orders, :stripe_refund_id, :string
    add_index :orders, :stripe_refund_id, unique: true

    remove_check_constraint :orders, "status IN ('pending', 'paid', 'shipped', 'canceled')", name: "orders_status_valid"
    add_check_constraint :orders, "status IN ('pending', 'paid', 'shipped', 'canceled', 'refunding', 'refunded')",
                         name: "orders_status_valid"

    # Todo pedido que chegou a ser pago (inclusive os estornados) tem a data do pagamento.
    remove_check_constraint :orders, "status NOT IN ('paid', 'shipped') OR paid_at IS NOT NULL", name: "orders_paid_has_date"
    add_check_constraint :orders, "status NOT IN ('paid', 'shipped', 'refunding', 'refunded') OR paid_at IS NOT NULL",
                         name: "orders_paid_has_date"

    # Estornado tem data e o id do estorno.
    add_check_constraint :orders, "status <> 'refunded' OR (refunded_at IS NOT NULL AND stripe_refund_id IS NOT NULL)",
                         name: "orders_refunded_has_refund"
  end
end
