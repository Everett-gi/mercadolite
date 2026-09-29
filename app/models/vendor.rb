# Vendedor do marketplace. Na fase 5, cada vendedor passa a ter um usuário dono,
# que administra os próprios produtos no painel.
class Vendor < ApplicationRecord
  MAX_NAME_LENGTH = 80
  MAX_DESCRIPTION_LENGTH = 2_000

  # restrict_with_error: não deixa apagar um vendedor que ainda tem produtos (o
  # histórico de pedidos da fase 4 depende deles). A chave estrangeira no banco garante
  # o mesmo, mas assim o erro chega como mensagem de validação, e não como exceção.
  has_many :products, dependent: :restrict_with_error

  # "normalizes" roda antes da validação: "  Loja   do  Zé " vira "Loja do Zé".
  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH },
                   uniqueness: { case_sensitive: false }
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
end
