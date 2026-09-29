# Um item do pedido: nome, preço e quantidade COPIADOS do produto na hora da compra. Se o
# produto mudar de nome ou de preço depois, o pedido continua mostrando o que foi comprado.
class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :product_name, presence: true, length: { maximum: 120 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100_000_000 }
  validates :quantity, numericality: {
    only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: CartItem::MAX_QUANTITY
  }

  # @return [Integer] preço congelado × quantidade, em centavos
  def line_total_cents
    unit_price_cents * quantity
  end
end
