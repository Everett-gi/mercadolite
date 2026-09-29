# "Meus pedidos". Tudo parte do escopo do usuário (policy_scope): o pedido de outra pessoa
# dá 404, como se não existisse.
class OrdersController < ApplicationController
  before_action :authenticate_user!
  # Redes de segurança do Pundit: quebram (com exceção) a ação que esquecer de autorizar.
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, only: :show

  # GET /orders
  def index
    @orders = policy_scope(Order).recent_first.includes(:items)
  end

  # GET /orders/:id
  def show
    @order = policy_scope(Order).find(params[:id])
    authorize @order
    @items = @order.items.order(:id)
  end
end
