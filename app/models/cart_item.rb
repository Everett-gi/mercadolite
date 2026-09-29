# Uma linha do carrinho: um produto e a quantidade desejada.
#
# Não há preço aqui. O total da linha é calculado com o preço ATUAL do produto, lido do
# banco — o navegador só informa QUAL produto e QUANTAS unidades.
class CartItem < ApplicationRecord
  MAX_QUANTITY = 10 # a mesma regra está no banco (cart_items_quantity_range)

  # touch: true — salvar ou apagar um item atualiza o updated_at do carrinho. É assim que o
  # job de limpeza sabe há quanto tempo ninguém mexe num carrinho.
  belongs_to :cart, touch: true
  belongs_to :product

  validates :quantity, numericality: {
    only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_QUANTITY
  }
  validate :product_must_be_purchasable, if: -> { new_record? || will_save_change_to_quantity? }

  # @return [Integer] preço atual do produto × quantidade, em centavos
  def line_total_cents
    product.price_cents * quantity
  end

  # O produto ainda está à venda e tem alguma unidade em estoque?
  #
  # @return [Boolean]
  def available?
    product.active? && product.in_stock?
  end

  # Pedimos mais unidades do que há em estoque agora? (o estoque pode ter baixado depois
  # que o item entrou no carrinho)
  #
  # @return [Boolean]
  def exceeds_stock?
    available? && quantity > product.stock_quantity
  end

  # Dá para comprar esta linha exatamente como está?
  #
  # @return [Boolean]
  def purchasable?
    available? && !exceeds_stock?
  end

  private

  # Consulta o estoque no momento em que o item é criado ou a quantidade muda. É uma
  # conferência amigável, não uma reserva: a garantia de estoque vem na confirmação do
  # pagamento (fase 4), com a linha do estoque travada no banco.
  def product_must_be_purchasable
    return if product.nil? || quantity.nil?

    if !product.active?
      errors.add(:product, :unavailable)
    elsif quantity > product.stock_quantity
      errors.add(:quantity, :exceeds_stock, count: product.stock_quantity)
    end
  end
end
