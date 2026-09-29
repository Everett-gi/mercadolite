# A página do carrinho. Singular (resource :cart): não há id na URL, porque cada sessão só
# enxerga o PRÓPRIO carrinho.
class CartsController < ApplicationController
  # GET /cart
  def show
    @lines = current_cart ? current_cart.lines.to_a : []
    @subtotal_cents = current_cart ? current_cart.subtotal_cents(@lines) : 0
  end
end
