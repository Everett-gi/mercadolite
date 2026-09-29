# Vendedores: quem anuncia produtos no marketplace.
class CreateVendors < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors do |t|
      t.string :name, null: false, limit: 80
      t.text :description, null: false, default: ""

      t.timestamps
    end

    # Nome único sem diferenciar maiúsculas: "Loja X" e "loja x" não podem coexistir.
    # O índice é sobre a EXPRESSÃO lower(name), por isso é escrito como string.
    add_index :vendors, "lower(name)", unique: true, name: "index_vendors_on_lower_name"
  end
end
