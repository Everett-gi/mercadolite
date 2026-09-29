# Eventos de webhook do Stripe já processados. O Stripe pode entregar o MESMO evento mais de
# uma vez (e até ao mesmo tempo); o índice único em event_id garante que cada um só produz
# efeito uma vez (idempotência).
class CreateStripeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_events do |t|
      t.string :event_id, null: false   # evt_... (o id do evento no Stripe)
      t.string :event_type, null: false # checkout.session.completed etc.
      t.datetime :created_at, null: false
    end

    add_index :stripe_events, :event_id, unique: true
  end
end
