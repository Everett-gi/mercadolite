# Rotas: a tabela que liga "verbo HTTP + caminho" a "controller#ação".
# Veja todas com:  bin/rails routes
Rails.application.routes.draw do
  # A vitrine é a página inicial.
  root "products#index"

  # Só leitura nesta fase: GET /products (lista) e GET /products/:id (detalhe).
  # O cadastro de produtos chega com o painel do vendedor (fase 5).
  resources :products, only: %i[index show]

  # O carrinho da sessão: singular, sem id na URL (GET /cart).
  resource :cart, only: :show
  # Itens do carrinho: POST /cart_items, PATCH e DELETE /cart_items/:id.
  resources :cart_items, only: %i[create update destroy]

  # Health check: responde 200 se a aplicação subiu. Usado pelo Docker/Caddy no deploy.
  get "up" => "rails/health#show", as: :rails_health_check
end
