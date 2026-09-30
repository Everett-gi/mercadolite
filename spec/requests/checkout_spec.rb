require "rails_helper"

RSpec.describe "Checkout", type: :request do
  let(:user) { create(:user) }
  let(:mug) { create(:product, name: "Caneca azul", price_cents: 4_990, stock: 10) }
  let(:session_id) { "cs_test_a1B2c3" }
  let(:checkout_url) { "https://checkout.stripe.com/c/pay/#{session_id}" }

  def log_in(user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
  end

  def add_to_cart(product, quantity: 1, **extra)
    post cart_items_path, params: { cart_item: { product_id: product.id, quantity: }.merge(extra) }
  end

  # Responde, no lugar do Stripe, à criação da sessão de pagamento. A primeira sessão tem o
  # id session_id; as seguintes, ids novos (como o Stripe faz para pedidos diferentes).
  def stub_session_create(url: checkout_url, status: 200)
    ids = Enumerator.new { |y| y << session_id; loop { y << "cs_test_#{SecureRandom.hex(4)}" } }
    stub_request(:post, "#{StripeHelpers::API}/checkout/sessions").to_return do
      body = if status == 200
        { id: ids.next, object: "checkout.session", url: }
      else
        { error: { type: "invalid_request_error", message: "recusado" } }
      end
      { status:, body: body.to_json }
    end
  end

  describe "POST /checkout" do
    it "exige login" do
      post checkout_path

      expect(response).to redirect_to(new_user_session_path)
    end

    context "logado, com produtos no carrinho" do
      before do
        log_in(user)
        add_to_cart(mug, quantity: 2)
      end

      it "cria o pedido e redireciona (303) para a página de pagamento do Stripe" do
        stub_session_create

        expect { post checkout_path }.to change(Order, :count).by(1)

        expect(response).to have_http_status(:see_other)
        expect(response.location).to eq(checkout_url)
        expect(Order.sole).to have_attributes(user:, status: "pending", total_cents: 9_980,
                                              stripe_checkout_session_id: session_id)
      end

      it "manda ao Stripe os valores do BANCO, e o marcador da sessão sem escapar" do
        stub = stub_session_create
        freeze_time do
          post checkout_path

          order = Order.sole
          expect(stub.with { |req|
            form = Rack::Utils.parse_nested_query(req.body)
            item = form["line_items"]["0"]
            item["quantity"] == "2" &&
              item["price_data"]["unit_amount"] == "4990" &&
              item["price_data"]["currency"] == "brl" &&
              item["price_data"]["product_data"]["name"] == "Caneca azul" &&
              form["payment_method_types"] == { "0" => "card" } &&
              form["client_reference_id"] == order.id.to_s &&
              form["customer_email"] == user.email &&
              form["expires_at"] == 30.minutes.from_now.to_i.to_s &&
              form["success_url"].end_with?("/checkout/success?session_id={CHECKOUT_SESSION_ID}") &&
              req.headers["Idempotency-Key"] == "mercadolite-order-#{order.id}-checkout"
          }).to have_been_made.once
        end
      end

      # O formulário não tem preço, mas um atacante pode mandar o que quiser.
      it "ignora preço mandado pelo navegador" do
        stub = stub_session_create

        post checkout_path, params: { total_cents: 1, unit_amount: 1, price_cents: 1 }

        expect(Order.sole.total_cents).to eq(9_980)
        expect(stub.with { |req| req.body.include?("[unit_amount]=4990") }).to have_been_made
      end

      it "se o Stripe recusa, o pedido é cancelado e o comprador volta ao carrinho" do
        stub_session_create(status: 400)

        post checkout_path

        expect(response).to redirect_to(cart_path)
        expect(flash[:alert]).to eq("Não foi possível abrir a página de pagamento agora. Tente de novo em instantes.")
        expect(Order.sole).to be_canceled
      end

      # Defesa em profundidade: o redirecionamento para fora da loja só vai para o Stripe.
      it "recusa redirecionar para uma URL que não é do Stripe" do
        stub_session_create(url: "https://site-do-atacante.example/pagar")

        post checkout_path

        expect(response).to redirect_to(cart_path)
        expect(Order.sole).to be_canceled
      end

      it "limita a 5 checkouts por minuto por conta" do
        stub_session_create
        5.times { post checkout_path }

        post checkout_path

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it "sem a chave do Stripe configurada, avisa e não cria pedido" do
      log_in(user)
      add_to_cart(mug)
      allow(StripeCheckout).to receive(:configured?).and_return(false)

      expect { post checkout_path }.not_to change(Order, :count)
      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to eq("O pagamento não está configurado neste servidor (falta a STRIPE_SECRET_KEY).")
    end

    it "recusa carrinho vazio, sem chamar o Stripe" do
      log_in(user)

      expect { post checkout_path }.not_to change(Order, :count)
      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to eq("Seu carrinho está vazio.")
    end

    it "recusa carrinho com item indisponível" do
      log_in(user)
      add_to_cart(mug)
      mug.update!(active: false)

      expect { post checkout_path }.not_to change(Order, :count)
      expect(response).to redirect_to(cart_path)
    end

    describe "proteção CSRF" do
      include_context "com proteção CSRF ligada"

      it "recusa o POST sem o token do formulário" do
        create(:cart, user:).add(mug, 1)
        get new_user_session_path # o login também exige o token: pega o do formulário
        login_token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
        post user_session_path, params: { authenticity_token: login_token,
                                          user: { email: user.email, password: user.password } }

        expect { post checkout_path }.not_to change(Order, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /checkout/success" do
    let(:order) { create(:order, user:, stripe_checkout_session_id: session_id) }

    def stub_session_retrieve(**overrides)
      stub_request(:get, "#{StripeHelpers::API}/checkout/sessions/#{session_id}")
        .to_return(status: 200, body: stripe_session_payload(order, **overrides).to_json)
    end

    it "consulta o Stripe e, se pago, confirma o pedido" do
      log_in(user)
      stub = stub_session_retrieve

      get success_checkout_path(session_id:)

      expect(stub).to have_been_made.once
      expect(response).to redirect_to(order_path(order))
      expect(order.reload).to be_paid
    end

    it "não confirma se o Stripe diz que ainda não foi pago" do
      log_in(user)
      stub_session_retrieve(payment_status: "unpaid")

      get success_checkout_path(session_id:)

      expect(order.reload).to be_pending
    end

    # A URL de retorno não prova nada: só serve para achar o pedido DO usuário e consultar.
    it "o session_id de um pedido de outra pessoa dá 404, sem consultar o Stripe" do
      log_in(create(:user))

      get success_checkout_path(session_id: order.stripe_checkout_session_id)

      expect(response).to have_http_status(:not_found)
      expect(order.reload).to be_pending
      expect(a_request(:get, /api.stripe.com/)).not_to have_been_made
    end

    it "pedido já pago não consulta o Stripe de novo" do
      order.update!(status: "paid", paid_at: Time.current)
      log_in(user)

      get success_checkout_path(session_id:)

      expect(response).to redirect_to(order_path(order))
      expect(a_request(:get, /api.stripe.com/)).not_to have_been_made
    end
  end
end
