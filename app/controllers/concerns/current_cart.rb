# Dá aos controllers o carrinho de quem está navegando.
#
# Um "concern" é um módulo (mixin) com o jeitão do Rails: o bloco "included" roda dentro da
# classe que faz "include CurrentCart", como se estivesse escrito nela.
#
# Quem está logado usa o carrinho da conta; o visitante, o carrinho cujo id está na sessão
# (e só se esse carrinho ainda for de visitante: um cookie antigo não alcança o carrinho de
# uma conta).
module CurrentCart
  extend ActiveSupport::Concern

  included do
    # Também disponível nas views (o contador do carrinho no cabeçalho).
    helper_method :current_cart
  end

  private

  # O carrinho atual, ou nil. NUNCA cria nada: uma simples visita (GET) não deve gravar no
  # banco — senão cada robô que passa pela loja criaria um carrinho.
  #
  # @return [Cart, nil]
  def current_cart
    return @current_cart if defined?(@current_cart)

    @current_cart =
      if user_signed_in?
        current_user.cart
      elsif session[:cart_id]
        Cart.guest.find_by(id: session[:cart_id])
      end
  end

  # O carrinho atual, criando um se ainda não houver. Só para ações que alteram o carrinho
  # (POST/PATCH/DELETE, protegidas por CSRF e rate limit).
  #
  # @return [Cart]
  def current_cart!
    @current_cart = current_cart || create_cart
  end

  def create_cart
    if user_signed_in?
      current_user.create_cart!
    else
      Cart.create!.tap { |cart| session[:cart_id] = cart.id }
    end
  rescue ActiveRecord::RecordNotUnique
    # Duas requisições da mesma conta ao mesmo tempo: a outra criou o carrinho primeiro
    # (o índice único de carts.user_id barrou esta). Usa o que ela criou.
    current_user.reload.cart
  end
end
