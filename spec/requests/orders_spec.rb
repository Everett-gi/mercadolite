require "rails_helper"

RSpec.describe "Meus pedidos", type: :request do
  let(:user) { create(:user) }
  let(:mug) { create(:product, name: "Caneca azul", price_cents: 4_990, stock: 10) }

  def log_in(user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
  end

  it "exige login" do
    get orders_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "lista só os pedidos do usuário" do
    mine = create(:order, user:)
    other = create(:order, user: create(:user))
    log_in(user)

    get orders_path

    expect(response.body).to include("Pedido nº #{mine.id}")
    expect(response.body).not_to include("Pedido nº #{other.id}")
  end

  it "mostra o pedido com o nome e o preço da hora da compra" do
    order = create(:order, :paid, user:, product: mug, quantity: 2)
    mug.update!(name: "Caneca renomeada", price_cents: 1_000)
    log_in(user)

    get order_path(order)

    expect(response.body).to include("Caneca azul", "R$ 49,90", "R$ 99,80", "Pago")
    expect(response.body).not_to include("Caneca renomeada")
  end

  # IDOR: trocar o id na URL para ver o pedido de outra pessoa.
  it "o pedido de outra pessoa dá 404, como se não existisse" do
    other = create(:order, user: create(:user))
    log_in(user)

    get order_path(other)

    expect(response).to have_http_status(:not_found)
  end
end
