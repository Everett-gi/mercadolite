# A página do carrinho. Singular (resource :cart): não há id na URL, porque cada sessão só
# enxerga o PRÓPRIO carrinho.
class CartsController < ApplicationController
  # GET /cart
  def show
    # Visitante que clicar em "Entre para finalizar a compra" volta para cá depois do login
    # (o Devise guarda o endereço na sessão).
    store_location_for(:user, cart_path) unless user_signed_in?
    @lines = current_cart ? current_cart.lines.to_a : []
    @subtotal_cents = current_cart ? current_cart.subtotal_cents(@lines) : 0
  end
end
