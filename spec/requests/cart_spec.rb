require "rails_helper"

RSpec.describe "Carrinho", type: :request do
  let(:product) { create(:product, name: "Caneca azul", price_cents: 4_990, stock: 5) }

  # Adiciona pelo formulário, como o navegador faria (sem Turbo: resposta HTML).
  def add_to_cart(product, quantity: 1, headers: {}, **extra)
    post cart_items_path,
         params: { cart_item: { product_id: product.id, quantity: }.merge(extra) },
         headers:
  end

  TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  describe "GET /cart" do
    it "mostra o carrinho vazio sem criar nada no banco" do
      expect { get cart_path }.not_to change(Cart, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Seu carrinho está vazio")
    end

    it "navegar pela loja (GET) não cria carrinho" do
      expect { get root_path; get product_path(product) }.not_to change(Cart, :count)
    end

    it "mostra as linhas, os avisos e o subtotal só do que pode ser comprado" do
      add_to_cart(product, quantity: 2)
      desativado = create(:product, name: "Bule antigo", price_cents: 9_000, stock: 5)
      add_to_cart(desativado)
      desativado.update!(active: false)
      product.inventory.update!(quantity: 1)

      get cart_path

      expect(response.body).to include("Caneca azul", "Bule antigo")
      expect(response.body).to include("Só resta 1 unidade em estoque. Ajuste a quantidade.")
      expect(response.body).to include("Este produto não está mais disponível.")
      expect(response.body).to include("R$ 0,00") # nenhuma linha pode ser comprada como está
    end
  end

  describe "POST /cart_items" do
    it "cria o carrinho da sessão e adiciona o produto" do
      expect { add_to_cart(product, quantity: 2) }.to change(Cart, :count).by(1)

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("2 unidades de Caneca azul foram adicionadas ao carrinho.")
      expect(response.body).to include("R$ 99,80")
    end

    it "reaproveita o carrinho da sessão nas requisições seguintes" do
      add_to_cart(product)

      expect { add_to_cart(product) }.not_to change(Cart, :count)
      expect(Cart.sole.items.sole.quantity).to eq(2)
    end

    # O formulário não tem campo de preço, mas um atacante pode enviar o que quiser.
    it "ignora preço enviado pelo navegador: o preço vem do banco" do
      add_to_cart(product, price_cents: 1, unit_price: "0,01")

      get cart_path
      expect(response.body).to include("R$ 49,90")
      expect(response.body).not_to include("R$ 0,01")
    end

    it "responde 404 para produto inativo e não cria carrinho" do
      inactive = create(:product, :inactive, stock: 5)

      expect { add_to_cart(inactive) }.not_to change(Cart, :count)
      expect(response).to have_http_status(:not_found)
    end

    [ "0", "11", "abc", "-1", "2.5", "3abc" ].each do |quantity|
      it "recusa a quantidade #{quantity.inspect}" do
        add_to_cart(product, quantity:)

        expect(response).to redirect_to(product_path(product))
        expect(flash[:alert]).to eq("Escolha uma quantidade de 1 a 10.")
        expect(CartItem.count).to eq(0)
      end
    end

    it "recusa quantidade acima do estoque" do
      add_to_cart(product, quantity: 6)

      expect(flash[:alert]).to eq("Quantidade maior que o estoque (só restam 5 unidades)")
      expect(CartItem.count).to eq(0)
    end

    it "responde com redirect (HTML) a quem aceita qualquer formato, como o curl" do
      add_to_cart(product, headers: { "Accept" => "*/*" })

      expect(response).to redirect_to(cart_path)
    end

    it "responde 400 quando faltam os parâmetros esperados" do
      post cart_items_path, params: { product_id: product.id }

      expect(response).to have_http_status(:bad_request)
    end

    context "com Turbo (o formulário da página do produto)" do
      it "atualiza o aviso e o contador sem sair da página" do
        add_to_cart(product, quantity: 1, headers: TURBO_STREAM)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('<turbo-stream action="update" target="flash">')
        expect(response.body).to include('<turbo-stream action="replace" target="cart_badge">')
        expect(response.body).to include("Caneca azul foi adicionado ao carrinho.")
      end

      it "responde 422 com a mensagem de erro" do
        add_to_cart(product, quantity: 6, headers: TURBO_STREAM)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("maior que o estoque")
      end
    end
  end

  describe "PATCH e DELETE /cart_items/:id" do
    before { add_to_cart(product) }

    let(:item) { CartItem.sole }

    it "muda a quantidade" do
      patch cart_item_path(item), params: { cart_item: { quantity: "3" } }

      expect(response).to redirect_to(cart_path)
      expect(flash[:notice]).to eq("Quantidade atualizada.")
      expect(item.reload.quantity).to eq(3)
    end

    it "recusa quantidade acima do estoque" do
      patch cart_item_path(item), params: { cart_item: { quantity: "6" } }

      expect(flash[:alert]).to eq("Quantidade maior que o estoque (só restam 5 unidades)")
      expect(item.reload.quantity).to eq(1)
    end

    it "remove o item" do
      expect { delete cart_item_path(item) }.to change(CartItem, :count).by(-1)
      expect(flash[:notice]).to eq("Produto removido do carrinho.")
    end
  end

  # IDOR: trocar o id na URL para mexer no carrinho de outra pessoa.
  describe "anti-IDOR" do
    let(:other_item) { create(:cart).add(create(:product, stock: 5), 1) }

    it "não deixa uma sessão alterar nem apagar item do carrinho de outra" do
      add_to_cart(product) # esta sessão tem o próprio carrinho

      patch cart_item_path(other_item), params: { cart_item: { quantity: "3" } }
      expect(response).to have_http_status(:not_found)

      delete cart_item_path(other_item)
      expect(response).to have_http_status(:not_found)

      expect(other_item.reload.quantity).to eq(1)
    end

    it "sem carrinho na sessão, qualquer id dá 404" do
      delete cart_item_path(other_item)

      expect(response).to have_http_status(:not_found)
      expect(CartItem.exists?(other_item.id)).to be(true)
    end
  end

  # No ambiente de teste a proteção CSRF vem desligada (config/environments/test.rb).
  # Aqui ela é ligada de propósito, para provar que funciona.
  describe "proteção CSRF" do
    around do |example|
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "recusa POST sem o token do formulário (como faria um site atacante)" do
      expect { add_to_cart(product) }.not_to change(CartItem, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "aceita o POST com o token que a própria página entregou" do
      get product_path(product)
      token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]

      post cart_items_path, params: {
        authenticity_token: token, cart_item: { product_id: product.id, quantity: 1 }
      }

      expect(response).to redirect_to(cart_path)
      expect(CartItem.count).to eq(1)
    end
  end

  describe "rate limit" do
    it "responde 429 depois de #{CartItemsController::RATE_LIMIT} alterações no mesmo minuto" do
      # Quantidade inválida: a requisição conta para o limite sem mexer no estoque.
      CartItemsController::RATE_LIMIT.times { add_to_cart(product, quantity: "0") }
      expect(response).to redirect_to(product_path(product)) # a última ainda passou

      add_to_cart(product, quantity: 1)

      expect(response).to have_http_status(:too_many_requests)
      expect(CartItem.count).to eq(0)
    end

    it "volta a aceitar depois que a janela de 1 minuto passa" do
      CartItemsController::RATE_LIMIT.times { add_to_cart(product, quantity: "0") }

      travel 61.seconds do
        add_to_cart(product, quantity: 1)
      end

      expect(response).to redirect_to(cart_path)
    end
  end

  # Regressão: um fecha-tag de ERB escrito DENTRO de um comentário ERB fechava o comentário
  # antes da hora, e o resto do texto aparecia na página (". %>" antes de cada aviso).
  it "não vaza pedaços de ERB no HTML das páginas" do
    add_to_cart(product)
    follow_redirect!
    expect(response.body).not_to include("%>")

    get product_path(product)
    expect(response.body).not_to include("%>")
  end

  describe "cookie de sessão" do
    it "é HttpOnly, SameSite=Lax e dura 30 dias" do
      add_to_cart(product)

      cookie = Array(response.headers["Set-Cookie"]).join("\n")
      expect(cookie).to match(/_mercadolite_session=/)
      expect(cookie).to match(/httponly/i)
      expect(cookie).to match(/samesite=lax/i)
      expect(cookie).to match(/expires=/i)
    end
  end
end
