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

  # Contas de comprador (Devise): /users/sign_in, /users/sign_up, /users/password/new...
  # Os controllers são os nossos (app/controllers/users/), que acrescentam rate limit e LGPD.
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    passwords: "users/passwords",
    confirmations: "users/confirmations"
  }

  # Checkout: POST /checkout (cria o pedido e vai para o Stripe) e GET /checkout/success
  # (a volta do Stripe depois do pagamento).
  resource :checkout, only: :create do
    get :success
  end
  # Meus pedidos: GET /orders e GET /orders/:id.
  resources :orders, only: %i[index show]
  # Webhooks do Stripe (servidor a servidor, autenticados pela assinatura).
  post "webhooks/stripe", to: "stripe_webhooks#create", as: :stripe_webhook

  # Páginas fixas exigidas pela LGPD, linkadas no cadastro e no rodapé.
  get "terms", to: "pages#terms", as: :terms
  get "privacy", to: "pages#privacy", as: :privacy

  # Health check: responde 200 se a aplicação subiu. Usado pelo Docker/Caddy no deploy.
  get "up" => "rails/health#show", as: :rails_health_check
end
