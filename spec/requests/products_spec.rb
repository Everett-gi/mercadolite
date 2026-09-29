require "rails_helper"

# Testes de request: fazem uma requisição HTTP de verdade à aplicação (sem navegador) e
# conferem a resposta (status, HTML). Cobrem rota + controller + view de uma vez.
RSpec.describe "Vitrine", type: :request do
  describe "GET /" do
    it "lista os produtos ativos com o preço formatado" do
      create(:product, name: "Caneca azul", price_cents: 4_990)
      create(:product, :inactive, name: "Produto escondido")

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Caneca azul", "R$ 49,90")
      expect(response.body).not_to include("Produto escondido")
    end

    it "aplica a busca vinda da URL" do
      create(:product, name: "Café especial")
      create(:product, name: "Caderno")

      get products_path, params: { q: "cafe" }

      expect(response.body).to include("Café especial")
      expect(response.body).not_to include("Caderno")
    end

    it "mostra os erros de filtro em português, sem quebrar a página" do
      get products_path, params: { min_price: "abc", sort: "hack" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Não foi possível aplicar os filtros")
      expect(response.body).to include("Preço mínimo deve ser um valor como 49,90")
    end

    it "pagina os resultados" do
      create_list(:product, ProductSearch::PER_PAGE + 1)

      get products_path, params: { page: 2 }

      expect(response.body).to include("Página 2 de 2")
      expect(response.body).to include("rel=\"prev\"")
    end

    it "trata página absurda como a última" do
      create_list(:product, 2)

      get products_path, params: { page: "999999999999" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2 produtos encontrados")
    end

    # O HTML de um nome malicioso precisa sair ESCAPADO (&lt;script&gt;), como texto.
    it "escapa HTML vindo do banco (XSS armazenado)" do
      create(:product, name: "<script>alert(1)</script>")

      get root_path

      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    end

    it "põe o nonce da CSP nos scripts do importmap" do
      get root_path

      nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
      expect(response.body).to include(%(<script type="importmap" data-turbo-track="reload" nonce="#{nonce}"))
    end
  end

  describe "GET /products/:id" do
    it "mostra o produto com vendedor, preço e estoque" do
      product = create(:product, name: "Bule", price_cents: 12_950, stock: 4,
                                 description: "Linha 1\nLinha 2")

      get product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bule", product.vendor.name, "R$ 129,50",
                                       "4 unidades disponíveis", "Linha 1\n<br />Linha 2")
    end

    it "mostra 'Esgotado' quando não há estoque" do
      get product_path(create(:product, stock: 0))

      expect(response.body).to include("Esgotado")
    end

    it "mostra a imagem pela variante do Active Storage" do
      get product_path(create(:product, :with_image))

      expect(response.body).to include("/rails/active_storage/representations/")
    end

    it "responde 404 para produto inativo (sem revelar que ele existe)" do
      get product_path(create(:product, :inactive))

      expect(response).to have_http_status(:not_found)
    end

    it "responde 404 para id inexistente" do
      get product_path(id: 0)

      expect(response).to have_http_status(:not_found)
    end

    # Sem o h(), o simple_format deixaria passar <img src="x"> (tirando só o onerror).
    it "escapa todo HTML da descrição, inclusive as tags que o sanitize aceitaria" do
      get product_path(create(:product, description: "<img src=x onerror=alert(1)> <b>oi</b>"))

      expect(response.body).not_to include("<img src=\"x\"", "<b>oi</b>")
      expect(response.body).to include("&lt;img src=x onerror=alert(1)&gt; &lt;b&gt;oi&lt;/b&gt;")
    end
  end
end
