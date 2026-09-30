# MercadoLite — Contexto do Projeto

> Handoff para o Claude Code. Este arquivo é **autossuficiente**: traz o blueprint do projeto e,
> no fim, a base de segurança e as convenções do portfólio. A central do portfólio é
> [Everett-gi/Projetos-e-ideias](https://github.com/Everett-gi/Projetos-e-ideias). Referências de qualidade:
> [DocSage](https://github.com/Everett-gi/docsage) e [PwnCheck](https://github.com/Everett-gi/pwncheck)
> (estrutura, testes, CI e as lições do modo tutorial).
> **Status:** 🚧 em construção — fases 1 (catálogo), 2 (carrinho), 3 (3a login + 3b checkout Stripe) e 4 (pedidos + estoque) concluídas. Próxima: fase 5 (painel do vendedor).

## Modo tutorial

O autor programa bem em **C e C++** (lógica, ponteiros, memória, compilação) e
está aprendendo Python; **Ruby e Rails são novos para ele** — este projeto também é o curso de Ruby.

- Explique cada passo e o **porquê**, com analogias a C/C++ quando ajudarem (ex.: tudo é objeto e a tipagem é dinâmica, blocos × lambdas do C++, módulos e mixins × herança múltipla, Bundler e gems × gerenciador de pacotes, a "convenção sobre configuração" do Rails, Active Record × SQL escrito à mão).
  Não explique lógica de programação básica; foque no que é novo.
- Cada fase concluída ganha uma lição em `docs/tutorial/fase-N-<tema>.md`, com exercícios e
  respostas no fim — o modelo são as lições do PwnCheck.
- Confirme rodando código qualquer afirmação técnica antes de escrevê-la numa lição.
- O autor roda este projeto no **WSL 2 (Ubuntu 24.04)** do Windows 11, com Ruby via `mise`,
  PostgreSQL no Docker Desktop e VS Code conectado ao WSL (Lição 00). Comandos do projeto nas
  lições e respostas: **bash, dentro do Ubuntu**; PowerShell só para passos do lado do Windows
  (instalar WSL, Docker Desktop, VS Code). Este repositório fica em `~/dev/mercadolite` (disco
  Linux), e não em `C:\dev` como os demais — o motivo está na Lição 00, seção 7.
- O autor pediu explicações **detalhadas**, com diagramas (Mermaid, que o GitHub renderiza) e
  glossário dos termos técnicos, tanto nas lições quanto nas respostas durante o trabalho.
- Commits no padrão Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `ci:`, `chore:`),
  um assunto por commit. Rode lint e testes sobre o estado final, logo antes de cada commit.

## Prioridades

**1) Segurança · 2) Clareza do código · 3) Funcionalidade.** Nessa ordem.

## O que é

Loja/marketplace com produtos, carrinho, **checkout via Stripe (modo teste, gratuito)**,
pedidos com status e controle de estoque. Bom candidato a carro-chefe de Ruby.

**Valor de portfólio:** fluxo de pagamento e estado de pedido "vendem" muito bem.

## Stack

Ruby **4.0.7** · Rails **8.1.4** · PostgreSQL 16 · Hotwire · Tailwind · Active Storage (libvips) ·
RSpec + FactoryBot · RuboCop (omakase) · Brakeman · bundler-audit · rails-i18n · dotenv ·
Devise 5 + devise-i18n · Mailpit (e-mail de desenvolvimento, no docker-compose) · Pundit 2.5 ·
gem `stripe` 19.6 (API `2026-08-26.dahlia`; só modo de teste) · WebMock (testes sem rede) ·
Stripe CLI (`stripe listen`, em desenvolvimento).

> **Versões:** escolhidas na fase 1 (estáveis em 29/09/2026) e registradas na lição
> `docs/tutorial/fase-1-catalogo.md`. A versão do Ruby aparece em `.ruby-version` e no
> `Dockerfile`: mude as duas juntas.

## Modelos

- **Vendor** · **Product** (vendor, preço, imagens) · **Inventory** (product, quantidade)
- **User** (Devise) · **Cart** (de visitante ou de um User) + **CartItem**
- **Order** (status: pending|paid|shipped|canceled|refunding|refunded) + **OrderItem** (nome e preço congelados)
- **StripeEvent** (eventos de webhook já processados: só `event_id` único e tipo)

## Funcionalidades principais

- Catálogo com busca/filtros · carrinho · checkout Stripe (teste)
- Pedidos e mudança de status · estoque · painel do vendedor

## Foco de segurança

**Verificação de assinatura** dos webhooks do Stripe; **idempotência** no processamento de
pagamento; autorização de pedidos (comprador vê os seus); **validação de preço no servidor**
(nunca confiar no valor vindo do cliente).

## Plano de build

1. ✅ Catálogo (produtos + imagens + busca/filtros/paginação)
   — lições: `docs/tutorial/00-ambiente-wsl.md`, `01-ruby-para-quem-vem-do-c.md`, `fase-1-catalogo.md`
2. ✅ Carrinho (sessão em cookie, CSRF, `rate_limit`, preço sempre do banco, limpeza diária)
   — lição: `docs/tutorial/fase-2-carrinho.md`
3. Login do comprador + checkout com Stripe em modo teste. O login veio para antes do
   checkout por decisão do autor: todo pedido nasce com dono (anti-IDOR). Dividida em duas:
   - ✅ **3a — Login** (Devise, confirmação de e-mail, rate limit, carrinho da conta, LGPD)
     — lição: `docs/tutorial/fase-3a-login.md`
   - ✅ **3b — Checkout** (Order + Pundit, Stripe Checkout com chave restrita, webhook com
     assinatura verificada e idempotente) — lição: `docs/tutorial/fase-3b-checkout.md`
4. ✅ Pedidos + estoque (baixa no pagamento confirmado, com `SELECT ... FOR UPDATE`; estorno
   automático; conciliação) — lição: `docs/tutorial/fase-4-estoque.md`
5. Painel do vendedor (login de vendedor, CRUD de produtos, upload validado pelo conteúdo)
6. Deploy (ver `docs/DEPLOY.md`)

## Decisões registradas

- **Sessão em cookie (Devise), e não JWT.** A base do portfólio pede JWT, mas este é um app
  que renderiza HTML no servidor; o autor aprovou a exceção, justificada no `SECURITY.md`.
- **Sem `credentials.yml.enc`/`master.key`:** segredos só em variáveis de ambiente
  (`SECRET_KEY_BASE` em produção). Nova variável → atualize o `.env.example`.
- **"Tipos explícitos" em Ruby:** não há type hints na linguagem. Cumprimos com colunas
  tipadas e restrições no banco, atributos tipados (Active Model) nas fronteiras, comentários
  YARD (`@param`/`@return`) nos métodos públicos e testes. RBS/Steep ficou fora por ora.
- **Dinheiro:** `Integer` em centavos no banco e no código; `BigDecimal` só para exibir.
- **Sem Kamal/Thruster:** o deploy é Docker Compose + Caddy (porta interna 3000).
- **Carrinho:** o id fica na sessão (cookie cifrado) e os itens no banco. `cart_items` **não
  tem preço**: ele é lido do produto na hora. O estoque é **conferido**, não reservado, no
  carrinho (a garantia vem no pagamento, fase 4). GET nunca cria carrinho.
- **Carrinho com dono (3a):** logado, o carrinho é o da conta (`carts.user_id`, único); no
  login, um gancho do Warden chama `Cart.claim` (o de visitante vira da conta ou é somado ao
  dela). A sessão de visitante só alcança `Cart.guest` (sem dono).
- **Senha (3a):** bcrypt custo 12; 15 a 72 caracteres **e** até 72 bytes; `PasswordPolicy`
  recusa senhas previsíveis; sem regras de composição (NIST SP 800-63B-4).
- **Revogação de sessão (3a):** `User#authenticatable_salt` inclui um `session_token`, trocado
  em todo logout (gancho `before_logout`, também na expiração). "Sair" encerra todas as
  sessões da conta. Timeout de 2 h sem uso.
- **Força bruta (3a):** `rate_limit` por IP e por e-mail (chave SHA-256), e não o `lockable`
  (que deixaria travar a conta dos outros). Modo `paranoid` contra enumeração.
- **E-mails (3a):** `deliver_later` depois do COMMIT (`ActiveRecord.after_all_transactions_commit`);
  os jobs de e-mail não logam argumentos (o token ia para o log).
- **LGPD (3a):** coleta mínima (e-mail + hash); aceite dos termos com data; exclusão da conta
  pelo titular (exige a senha); contas não confirmadas apagadas em 7 dias.
- **Checkout (3b):** Stripe Checkout **hospedado** (o cartão nunca passa pela loja). `Order.place`
  cria o pedido do carrinho copiando nome e preço do banco para `order_items`; os itens enviados
  ao Stripe saem do pedido. Um pedido novo por checkout; só cartão; página expira em 30 min;
  falha da API → pedido cancelado. Chave de idempotência por pedido
  (`mercadolite-order-<id>-checkout`). A URL devolvida precisa ser de `checkout.stripe.com`.
- **Confirmação (3b):** só o Stripe confirma: webhook assinado ou `sessions.retrieve` na volta
  (`/checkout/success`, que só acha pedidos do usuário). `confirm_payment!` confere sessão,
  `payment_status`, valor e moeda, dentro de `with_lock`. `StripeEvent.process` grava o evento
  (índice único) na MESMA transação do efeito. Todo evento verificado recebe 200 (senão o
  Stripe reenvia por dias); assinatura inválida → 400; corpo > 64 KB → 413.
- **Chaves do Stripe (3b):** só de teste (`StripeKeys.test_key?`; o boot falha com `_live_`),
  de preferência restrita (`Checkout Sessions: Write` e, desde a fase 4, `Refunds: Write`). Nos testes, valores fixos no
  initializer e WebMock bloqueando a rede. Tempo máximo: 5 s para conectar, 20 s para ler.
- **Pundit (3b):** negação por padrão (`ApplicationPolicy`), `policy_scope` + `authorize` (as duas
  camadas, de propósito), `verify_authorized`/`verify_policy_scoped`, e
  `Pundit::NotAuthorizedError` → 404 (não revela que o registro existe).
- **Estoque (4):** baixa só no pagamento confirmado (não há reserva), dentro do `with_lock` do
  pedido: `Inventory.withdraw` trava as linhas com `FOR UPDATE` em ordem de `product_id`
  (contra deadlock), confere TUDO antes de baixar (tudo ou nada; nada de
  `ActiveRecord::Rollback` em transação aninhada) e devolve `false` se faltar.
- **Estorno (4):** pago sem estoque → `refunding`; `RefundOrderJob` (enfileirado com
  `after_all_transactions_commit`) chama `StripeRefunds#refund_in_full` (sem `amount`, chave
  `mercadolite-order-<id>-refund`), com `retry_on` só para erros passageiros (5 tentativas);
  `refunded` só se o Stripe devolve `pending`/`succeeded`. Estorno inteiro, nunca parcial.
- **Conciliação (4):** `ReconcileOrdersJob` a cada 15 min (produção): pendentes de 1 h a 3 dias,
  do mais novo ao mais antigo, decididos pelo Stripe (`StripeCheckout#sync` →
  `Order#apply_checkout_session!`), nunca por tempo; sem sessão → `cancel_unstarted!`;
  `refunding` há mais de 1 h → estorno de novo.
- **LGPD (3b):** excluir a conta deixa os pedidos sem dono (`on_delete: :nullify`); ao Stripe vão
  só o e-mail e os itens; `stripe_events` guarda só id e tipo; a chave `data` (o conteúdo dos
  eventos) é filtrada do log.

## Mapa dos arquivos

| Arquivo | Responsabilidade |
|---|---|
| `lib/brl.rb` | **Funções puras** de dinheiro: `Brl.parse_cents("49,90") → 4990`, `Brl.from_cents → BigDecimal`. |
| `lib/pagination.rb` | **Valor puro** (`Data`) de paginação; prende a página pedida no intervalo válido. |
| `app/models/vendor.rb`, `product.rb`, `inventory.rb` | Modelos; validações espelham as restrições do banco. `Product.matching` é a busca (placeholder + `sanitize_sql_like` + `unaccent`). |
| `app/models/product_search.rb` | Form object dos filtros: atributos tipados, validação, ordenação por allowlist (`SORTS`). |
| `app/controllers/products_controller.rb` | `index` (busca + paginação) e `show` (404 para inativo). |
| `app/views/products/`, `app/views/shared/` | Vitrine (Tailwind); tudo escapado — descrição com `simple_format(h(...))`. |
| `config/initializers/content_security_policy.rb` | CSP estrita com nonce por requisição. |
| `config/initializers/security_headers.rb` | `Permissions-Policy` moderno e `X-Frame-Options: DENY`. |
| `config/locales/pt-BR.yml` | Nomes de modelos/atributos e mensagens de erro próprias. |
| `db/seeds.rb` | Dados de exemplo idempotentes (imagens geradas com libvips). |
| `lib/quantity.rb` | **Função pura** estrita: `Quantity.parse("3", max: 10) → 3`; qualquer coisa fora de `\A\d{1,3}\z` e 1..max → `nil`. |
| `app/models/cart.rb`, `cart_item.rb` | Carrinho: `Cart#add` soma à linha existente (e trata a corrida no índice único); `CartItem` valida 1..10 e o estoque; subtotal com o preço atual. |
| `app/controllers/concerns/current_cart.rb` | `current_cart` (só procura; GET nunca cria) e `current_cart!` (cria, nas ações que alteram). |
| `app/controllers/carts_controller.rb`, `cart_items_controller.rb` | `GET /cart`; `POST/PATCH/DELETE /cart_items` com `params.expect`, `rate_limit` (30/min por IP) e anti-IDOR (`current_cart.items.find`). HTML primeiro no `respond_to`, depois Turbo Stream. |
| `app/jobs/purge_abandoned_carts_job.rb` + `config/recurring.yml` | Apaga carrinhos parados há 30 dias, todo dia às 4h de Brasília (Solid Queue). |
| `config/initializers/session_store.rb` | Cookie de sessão: 30 dias, `SameSite=Lax`, `Secure` em produção. |
| `public/*.html` | Páginas de erro em português, incluindo a 429 do rate limit. |
| `app/models/user.rb` | Conta (Devise): senha 15..72 bytes, aceite dos termos, `session_token` no sal da sessão, e-mails por job depois do commit. |
| `lib/password_policy.rb` | **Função pura**: `PasswordPolicy.weakness(senha, email:)` → `:repetitive`, `:service_name`, `:email` ou `nil`. |
| `config/initializers/devise.rb` | Só as opções usadas, comentadas: paranoid, custo, tamanho da senha, validades, timeout. |
| `config/initializers/warden_hooks.rb` | Ganchos: no login, `Cart.claim`; antes do logout, `end_all_sessions!`. |
| `config/initializers/action_mailer.rb` | `MailDeliveryJob.log_arguments = false` (tokens fora do log). |
| `app/controllers/users/` | Controllers do Devise herdados, com `rate_limit` por IP e por e-mail; `registrations#destroy` exige a senha. |
| `app/controllers/concerns/email_rate_limit.rb` | Chave do limite por e-mail (SHA-256 do e-mail normalizado). |
| `app/views/users/` | Telas e e-mails do Devise em português (`config.scoped_views = true`). |
| `app/controllers/pages_controller.rb`, `app/views/pages/` | Termos de Uso (`/terms`) e Política de Privacidade (`/privacy`). |
| `app/jobs/purge_unconfirmed_users_job.rb` | Apaga contas não confirmadas há mais de 7 dias (4h10 de Brasília). |
| `app/models/order.rb`, `order_item.rb` | Pedido: `Order.place` (do carrinho, preço do banco), `confirm_payment!` (baixa ou estorno), `apply_checkout_session!`, `cancel_checkout!`, `cancel_unstarted!` e `record_refund!` (idempotentes, com `with_lock`). |
| `app/models/inventory.rb` | `Inventory.withdraw(product_id => qtd)`: baixa tudo ou nada, com `FOR UPDATE` em ordem de `product_id`. |
| `app/models/stripe_refunds.rb` | PORO da API de estornos: `refund_in_full` (chave de idempotência por pedido). |
| `app/jobs/refund_order_job.rb`, `reconcile_orders_job.rb` | Estorno com novas tentativas; conciliação a cada 15 min (`config/recurring.yml`). |
| `app/models/stripe_checkout.rb` | PORO da API do Stripe: `start` (cria a sessão, confere o host) e `sync` (consulta e confirma). |
| `app/models/stripe_event.rb` | `StripeEvent.process(event)`: um evento uma vez só, na mesma transação do efeito. |
| `lib/stripe_keys.rb` | **Função pura**: `test_key?` (`sk`/`rk` + letras + `_test_`) e `webhook_secret?` (`whsec_`). |
| `config/initializers/stripe.rb` | Chaves do ambiente (fixas nos testes), recusa de chave de produção, timeouts. |
| `app/policies/` | `ApplicationPolicy` (nega tudo) e `OrderPolicy` (dono vê e paga; escopo por usuário). |
| `app/controllers/checkouts_controller.rb` | `POST /checkout` (pedido + redirecionamento 303 ao Stripe, `rate_limit` 5/min por conta) e `GET /checkout/success`. |
| `app/controllers/orders_controller.rb`, `app/views/orders/` | "Meus pedidos" (`policy_scope`), com o status em português (`order_status_badge`). |
| `app/controllers/stripe_webhooks_controller.rb` | `POST /webhooks/stripe` (`ActionController::API`: sem CSRF nem sessão); corpo cru, 64 KB, `construct_event`. |
| `config/brakeman.ignore` | Falso positivo de redirecionamento (URL da API do Stripe, host conferido), com justificativa. |
| `spec/` | `lib/` (puras), `models/`, `policies/`, `helpers/`, `jobs/`, `db/`, `requests/` (XSS, SQL injection, CSP, CSRF ligado, IDOR, 429, login: enumeração, cookie copiado, rate limit por e-mail; webhooks: assinatura, replay, idempotência, log). `spec/models/order_concurrency_spec.rb`: duas conexões reais (sem transação de teste). `spec/support/forgery_protection.rb`: contexto "com proteção CSRF ligada"; `spec/support/stripe_helpers.rb`: sessões e eventos assinados de mentira. |

**Regras de arquitetura:**
- Lógica pura (sem banco/HTTP/Rails) vai em `lib/`, com teste em `spec/lib/`.
- Toda regra de integridade importante existe no modelo **e** no banco (CHECK/UNIQUE/FK).
- Nada da URL vira estrutura de SQL: valores por placeholder/hash, nomes por allowlist.
- Buscar sempre a partir do escopo permitido (`Product.active.find`,
  `current_cart.items.find`, `policy_scope(Order).find`).
- Toda garantia de segurança tem teste próprio, e um teste novo precisa ser visto falhando com
  o bug antes de ser aceito.

## Comandos (bash, no Ubuntu/WSL, dentro de `~/dev/mercadolite`)

```bash
docker compose up -d                 # PostgreSQL 16 + Mailpit (e-mails em http://localhost:8025)
bin/rails db:prepare db:seed         # bancos + dados de exemplo (db:migrate depois de um git pull)
bin/dev                              # servidor + Tailwind (http://localhost:3000)
stripe listen --events checkout.session.completed,checkout.session.async_payment_succeeded,checkout.session.expired,checkout.session.async_payment_failed --forward-to localhost:3000/webhooks/stripe   # webhooks em dev (whsec_ → .env)
bundle exec rspec                    # testes
bin/rubocop                          # lint (o CI exige zero ofensas)
bin/brakeman && bin/bundler-audit    # scans de segurança
bin/ci                               # tudo o que o CI roda
```

## Armadilhas conhecidas (fases 1 a 3a)

- **`config.permissions_policy` do Rails 8.1 emite o cabeçalho antigo `Feature-Policy`.** O
  `Permissions-Policy` é enviado via `default_headers` em `security_headers.rb`.
- **`simple_format` sanitiza, não escapa** (deixa `<img>`, `<b>`): use `simple_format(h(texto))`.
- **Marcel (Active Storage) confia no nome/tipo declarado quando os bytes não têm
  assinatura:** texto disfarçado de `.png` passa. Teste `pending` em `product_spec.rb` cobra a
  correção na fase 5 (decodificar com libvips).
- **Atributo `:integer` do Active Model converte com `to_i`:** `"abc"` → 0, `"12abc"` → 12.
  Conversão não é validação.
- **Rodar comandos com locale US-ASCII quebra o `rails new`/geradores** (o `.gitignore` tem
  UTF-8): use `LANG=C.UTF-8`.
- **`Integer("08")` levanta erro (octal)**: use `Integer(texto, 10)` ou valide antes.
- **`rate_limit` usa o cache store resolvido quando a classe carrega.** Com o `:null_store`
  (padrão do ambiente de teste), o limite não existe. Os testes usam `:memory_store`, limpo
  antes de cada exemplo (sem limpar, os contadores vazam entre testes e as falhas mudam com a
  ordem).
- **Um comentário ERB (`<%# ... %>`) termina no primeiro `%>`**: não cite a tag de saída do
  ERB dentro dele. Há teste que procura `%>` vazando no HTML.
- **`respond_to`: quem aceita `*/*` (curl) recebe o primeiro formato declarado.** Deixe
  `format.html` antes de `format.turbo_stream`.
- **`build(:modelo)` não roda callbacks de criação:** um `Product` só construído não tem
  `inventory`. Use `Product#stock_quantity` (nil → 0) e, nas fábricas,
  `association ..., strategy: :create` quando o objeto precisar existir no banco.
- **`recurring.yml` segue o `config.time_zone`:** "every day at 4am" é 4h de Brasília (07:00 UTC).
- **`numericality: { in: 1..10 }` gera "deve estar em 1..10"**: prefira
  `greater_than_or_equal_to`/`less_than_or_equal_to` (mensagens melhores no rails-i18n).
- **`image_processing` 2.x não traz mais a `ruby-vips`:** ela está declarada no `Gemfile`
  com `require: false` (carregá-la no boot abriria a libvips nativa e quebraria jobs de CI
  sem libvips; as miniaturas e o `db/seeds.rb` a carregam sob demanda). Um teste gera uma miniatura de verdade; o CI de
  uma atualização que tire a gem do bundle fica vermelho. Leia o changelog de toda
  atualização *major* do Dependabot antes do merge.
- **Status 422 no Rack atual é `:unprocessable_content`** (`:unprocessable_entity` está
  obsoleto e gera aviso).
- **O bcrypt ignora, em silêncio, o que passa de 72 BYTES da senha** (e o Devise aceitaria
  128 caracteres). O `User` limita a 72 bytes; acento conta 2.
- **O Active Job escreve os argumentos dos jobs no log**, e o token do link de redefinição de
  senha é um deles. `ActionMailer::MailDeliveryJob.log_arguments = false`, com teste.
- **`validates ..., acceptance: true` é pulada quando o campo vem `nil`**: use
  `acceptance: { allow_nil: false }`.
- **O Rails 8.1 não espera o COMMIT para enfileirar jobs** (`enqueue_after_transaction_commit`
  é `false`): use `ActiveRecord.after_all_transactions_commit { ... }`.
- **O Devise carrega o `bcrypt` sob demanda:** spec que usa `BCrypt::` direto precisa de
  `require "bcrypt"` (senão falha só em algumas ordens, como a semente 11802).
- **`items.find_or_initialize_by` constrói pela associação:** uma linha recusada fica
  pendurada, não salva, em `cart.items` em memória. Para montar sem sujar a lista, use
  `CartItem.find_or_initialize_by(cart_id: id, ...)`.
- **Dentro de um controller do Devise, `authenticate_user!` não faz nada** sem `force: true`.
  Ações que exigem login ficam em controllers próprios.
- **Um login que falha calcula 2 hashes bcrypt** (a tela é re-renderizada com um `User.new`
  que recebe a senha). O Devise faz o hash **na atribuição** da senha: cada cadastro custa
  ~250 ms de CPU, mesmo inválido.
- **Timeout do Devise redireciona duas vezes:** para a página pedida (com o aviso) e, dela,
  para o login.
- **`localhost` e `127.0.0.1` têm cookies separados:** os links dos e-mails usam
  `default_url_options` (`localhost:3000`). Teste no navegador sempre em `localhost`.
- **Cada formulário tem o próprio token CSRF** (preso à ação): num teste, pegue o token do
  formulário certo, não o primeiro da página.
- **O token de confirmação do Devise fica no banco como está e não é apagado depois de usado**
  (o de redefinição é HMAC e é apagado).
- **`bin/rails server` sozinho não recompila o Tailwind:** use `bin/dev`, ou rode
  `bin/rails tailwindcss:build` depois de criar classes novas nas views.
- **`db:prepare` carrega os seeds sempre que CRIA o banco principal, em qualquer ambiente**
  (teste no CI, produção no primeiro deploy via `bin/docker-entrypoint`). Por isso os seeds
  são um *no-op* fora do desenvolvimento (com `return`, nunca `abort`), com teste em
  `spec/db/seeds_spec.rb`.

### Descobertas na fase 3b

- **A chave restrita de uma sandbox criada pela Stripe CLI começa com `rkcs_test_`**, e não
  `rk_test_`: por isso `StripeKeys::TEST_KEY` aceita `(sk|rk)[a-z]*_test_`.
- **O `Stripe::StripeClient` ignora o `Stripe.api_base` global**: para outro servidor, passe
  `api_base:` ao cliente.
- **A gem do Stripe confia só no próprio bundle de CAs** (`lib/data/ca-certificates.crt`).
  Atrás de um proxy que troca certificados, use `Stripe.ca_bundle_path`; nunca desligue a
  verificação.
- **CSP `form-action` vale também para o destino do redirecionamento** depois do envio (o
  `POST /checkout` → `checkout.stripe.com`), e a mensagem do Chromium cita a URL de origem.
- **O Turbo segue redirecionamentos com `fetch`**, e o `connect-src 'self'` barra o Stripe: o
  botão do checkout usa `data-turbo=false` (não abra o `connect-src`).
- **O helper de URL escapa `{CHECKOUT_SESSION_ID}`** (`%7B...%7D`): monte a `success_url` à mão.
- **`redirect_to` para outro host levanta `OpenRedirectError`** (`action_on_open_redirect =
  :raise`): use `allow_other_host: true` só depois de conferir o host.
- **O Rails escreve no log o corpo JSON de toda requisição (nível `info`)**: o webhook levava
  nome e CEP do comprador. `filter_parameters` tem `/\Adata\z/` (um filtro em texto, `:data`,
  pegaria também `metadata`).
- **Constante de `lib/` não existe num initializer** (autoload do Zeitwerk ainda desligado):
  `NameError`. Use `Rails.application.config.after_initialize`.
- **Tradução de enum:** `human_attribute_name("status.paid")` procura em
  `activerecord.attributes.order/status.paid` (chave com barra).
- **Uma violação de `CHECK` aborta a transação do PostgreSQL** (`current transaction is
  aborted`): nos testes, um exemplo por violação.
- **Corpo das chamadas à API do Stripe é formulário**: com `Rack::Utils.parse_nested_query`,
  arrays chegam como hashes (`{"0" => "card"}`).
- **Dublês de API precisam ser realistas**: um stub que devolve sempre o mesmo id de sessão
  quebra no índice único. Gere ids novos.
- **Concorrência de verdade exige `self.use_transactional_tests = false`** (a transação do
  teste esconde os dados da outra conexão) e limpeza manual no `after`. Reler (`reload`) não
  substitui o `FOR UPDATE`: sem a trava, a outra conexão ainda não fez COMMIT.
- **A tolerância da assinatura só recusa eventos velhos** (> 300 s); assinados no futuro são
  aceitos (só quem tem o `whsec_` assina).
- **Os rate limits valem para você no navegador** (5 checkouts/min, 5 logins/15 min por
  e-mail): reiniciar o `bin/dev` zera os contadores (ficam na memória).

### Descobertas na fase 4

- **Atualização perdida não viola `CHECK`:** sem `FOR UPDATE`, duas vendas da última unidade
  gravam `0` duas vezes (conferido: `[:vendeu, :vendeu, 0]`).
- **`ActiveRecord::Rollback` dentro de transação ANINHADA é engolido** (o `transaction` interno
  só se junta ao de fora): o que já foi alterado fica. Use `transaction(requires_new: true)`
  (savepoint) ou confira tudo antes de alterar.
- **Teste de "tudo ou nada" com vários itens:** o item que falta precisa ser o ÚLTIMO na
  ordem de processamento; senão, o teste passa até com o código errado.
- **`let` preguiçoso referenciado pela primeira vez dentro de uma transação desfeita** some
  com ela: crie o registro antes (`session` / `let!`).
- **Em produção, a fila do Solid Queue fica em outro banco (`queue`)**, fora da transação:
  enfileire jobs que dependem do COMMIT com `ActiveRecord.after_all_transactions_commit`.
- **`retry_on ... attempts: 5`** conta a primeira execução: 5 chamadas; `:polynomially_longer`
  espera `n⁴ + 2` s (3, 18, 83, 258) mais *jitter*.
- **`perform_enqueued_jobs` no RSpec, com job que termina em erro,** levanta `NameError`
  (`tagged_logger`), e não o erro do job: para testar esgotamento, conte as chamadas.
- **Conciliação por "mais antigos primeiro" trava** (*head-of-line blocking*) com pedidos que
  sempre dão erro (sessões de outra conta do Stripe): processe do mais novo e dê um prazo.
- **Saída antecipada antes do `authorize`** exige `skip_authorization` (por causa do
  `verify_authorized`).
- **Nunca desfaça experimentos com `git checkout <arquivo>`** num arquivo com mudanças ainda não
  commitadas: volta ao último commit e apaga o trabalho. Use cópias (`cp`).

## Como começar (feito na fase 1)

O esqueleto foi gerado com `rails new . --database=postgresql --css=tailwind --skip-git
--skip-test --skip --skip-kamal --skip-thruster --skip-action-mailbox --skip-action-text
--skip-jbuilder --skip-action-cable` (o porquê de cada opção está na lição da fase 1). CI,
Dependabot, `.env.example`, `docker-compose.yml` (PostgreSQL de dev) e `SECURITY.md` já
existem. Para rodar numa máquina nova, siga a Lição 00.

**Stripe (desde a fase 3b):** o autor usa a sandbox "Área restrita de MercadoLite", sem ativar
o modo de produção. Só chaves de **teste**, de preferência **restrita** (`rk_test_`, com
`Checkout Sessions: Write` e `Refunds: Write`), e só no `.env` (nunca no chat nem no Git). Em
desenvolvimento, os webhooks chegam pela Stripe CLI (`stripe listen`, que mostra o `whsec_`;
instalação pelo `apt` na lição da fase 3b). Para verificações reais feitas pelo Claude, o
autor autorizou criar sandboxes anônimas pela CLI (`stripe sandbox create --email`), com as
chaves só no container e apagadas no fim. **Para a fase 5:** o vendedor é um papel novo
(RBAC com Pundit), sempre com escopo por dono; o upload de imagens deve ser validado pelo
conteúdo (o teste `pending` de `product_spec.rb` cobra isso); marcar `paid → shipped`.

## Base de segurança do portfólio (Definition of Done)

Vale para todos os projetos do portfólio, este incluído:

- **Segredos** só em variáveis de ambiente (`.env` fora do Git e da imagem). Nunca hardcoded.
- **Senhas** com hash Argon2/BCrypt. **Nunca** texto puro ou hash fraco.
- **Autenticação** por JWT (access + refresh com rotação) onde houver login.
- **Autorização** com verificação de posse por recurso (anti-IDOR) e RBAC quando aplicável.
- **SQL Injection**: acesso ao banco só via ORM / parâmetros ligados. Nunca concatenar SQL.
- **Validação de entrada** com schema/DTO e limite de tamanho de payload.
- **Rate limiting** em login e endpoints sensíveis.
- **Cabeçalhos de segurança** (HSTS, CSP, X-Content-Type-Options) e **HTTPS** em produção.
- **Dependências** escaneadas no CI + Dependabot.
- **Logs** sem segredos nem dados pessoais.
- **LGPD**: coleta mínima, aceite de termos e exclusão de conta quando houver dados de usuário.
- Um **`SECURITY.md`** descrevendo essas medidas aplicadas a este repositório (crie-o na
  primeira fase com código e mantenha-o atualizado).

## Convenções de código

- Comentários e documentação do código em **português**; nomes de código em **inglês**.
- Tipos explícitos sempre (em Python, *type hints*).
- Toda função pura nova vem acompanhada de teste.
- Mensagens de erro da API/interface em português (é o usuário que lê).
- Ao criar uma variável de ambiente nova, atualize o `.env.example` (valores fictícios).

## Ferramentas — Ruby (Rails)

| | |
|---|---|
| Migrations | Active Record |
| Auth | Devise + Pundit |
| Testes | RSpec |
| Lint | RuboCop |
| Scan de segurança | Brakeman + bundler-audit |

## Deploy

Guia em `docs/DEPLOY.md` (porta interna 3000).
