# Dá aos controllers o carrinho da sessão atual.
#
# Um "concern" é um módulo (mixin) com o jeitão do Rails: o bloco "included" roda dentro da
# classe que faz "include CurrentCart", como se estivesse escrito nela.
module CurrentCart
  extend ActiveSupport::Concern

  included do
    # Também disponível nas views (o contador do carrinho no cabeçalho).
    helper_method :current_cart
  end

  private

  # O carrinho desta sessão, ou nil. NUNCA cria nada: uma simples visita (GET) não deve
  # gravar no banco — senão cada robô que passa pela loja criaria um carrinho.
  #
  # @return [Cart, nil]
  def current_cart
    return @current_cart if defined?(@current_cart)

    @current_cart = session[:cart_id] && Cart.find_by(id: session[:cart_id])
  end

  # O carrinho desta sessão, criando um se ainda não houver. Só para ações que alteram
  # o carrinho (POST/PATCH/DELETE, protegidas por CSRF e rate limit).
  #
  # @return [Cart]
  def current_cart!
    current_cart || Cart.create!.tap do |cart|
      session[:cart_id] = cart.id
      @current_cart = cart
    end
  end
end
