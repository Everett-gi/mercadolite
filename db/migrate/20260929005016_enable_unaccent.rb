# Liga a extensão "unaccent" do PostgreSQL: unaccent('café') = 'cafe'. A busca do
# catálogo usa isso para achar "café" quando alguém digita "cafe" (e vice-versa).
class EnableUnaccent < ActiveRecord::Migration[8.1]
  def change
    enable_extension "unaccent"
  end
end
