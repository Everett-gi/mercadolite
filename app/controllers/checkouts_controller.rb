# O checkout: transforma o carrinho num pedido e manda o comprador para a página de
# pagamento do Stripe (Stripe Checkout). O número do cartão nunca passa por este servidor.
#
# Segurança:
# - Só logado (todo pedido nasce com dono) e com rate limit por conta.
# - Os valores saem do banco (Order.place), nunca do navegador.
# - A volta do Stripe (success) não marca nada como pago por conta própria: ela CONSULTA o
#   Stripe. Quem confirma o pagamento é o Stripe (webhook assinado ou resposta da API).
class CheckoutsController < ApplicationController
  before_action :authenticate_user!
  # Cada ação precisa chamar authorize: se alguém esquecer, o teste quebra (exceção).
  after_action :verify_authorized

  # Criar um checkout chama a API do Stripe: limitar evita que alguém use a loja para gerar
  # milhares de sessões de pagamento.
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { current_user.id }
  rate_limit to: 20, within: 1.minute, only: :success, by: -> { current_user.id }

  # POST /checkout
  def create
    order = Order.place(current_cart, current_user)
    authorize order
    return redirect_to(cart_path, alert: order.errors.full_messages.to_sentence) if order.errors.any?
    return redirect_to(cart_path, alert: t(".not_configured")) unless StripeCheckout.configured?

    redirect_to start_payment(order), allow_other_host: true, status: :see_other
  rescue Stripe::StripeError, StripeCheckout::UnexpectedResponse => e
    # O pedido fica cancelado (nunca foi para pagamento), e a falha vai para o log sem dado
    # pessoal: só a classe do erro e o id do pedido.
    order&.update_columns(status: "canceled", canceled_at: Time.current) if order&.persisted?
    Rails.logger.error("[checkout] falha ao criar a sessão do pedido #{order&.id}: #{e.class}")
    redirect_to cart_path, alert: t(".unavailable")
  end

  # GET /checkout/success?session_id=cs_test_...
  #
  # Para onde o Stripe manda o comprador depois de pagar. O session_id da URL NÃO é prova de
  # pagamento (qualquer um pode digitar esta URL): ele só diz qual pedido consultar, e o
  # pedido é procurado só entre os do usuário (anti-IDOR).
  def success
    order = policy_scope(Order).find_by!(stripe_checkout_session_id: params.expect(:session_id))
    authorize order, :show?
    StripeCheckout.new.sync(order) if order.pending?
    redirect_to order_path(order), status: :see_other
  rescue Stripe::StripeError => e
    # Sem resposta do Stripe agora: o webhook confirma depois. O comprador vê "aguardando".
    Rails.logger.warn("[checkout] falha ao consultar a sessão do pedido #{order&.id}: #{e.class}")
    redirect_to order_path(order), status: :see_other
  end

  private

  # A URL de retorno leva o marcador {CHECKOUT_SESSION_ID}, que o Stripe troca pelo id da
  # sessão. Ele é montado À MÃO: o helper de URL escaparia as chaves ({ vira %7B), e o
  # Stripe não reconheceria o marcador.
  #
  # @return [String] a URL da página de pagamento
  def start_payment(order)
    StripeCheckout.new.start(
      order,
      success_url: "#{success_checkout_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: cart_url
    )
  end
end
