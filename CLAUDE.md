# MercadoLite — Contexto do Projeto

> Handoff para o Claude Code. Este arquivo é **autossuficiente**: traz o blueprint do projeto e,
> no fim, a base de segurança e as convenções do portfólio. A central do portfólio é
> [Everett-gi/Projetos-e-ideias](https://github.com/Everett-gi/Projetos-e-ideias). Referências de qualidade:
> [DocSage](https://github.com/Everett-gi/docsage) e [PwnCheck](https://github.com/Everett-gi/pwncheck)
> (estrutura, testes, CI e as lições do modo tutorial).
> **Status:** 🚧 em construção — fase 1 concluída (catálogo). Próxima: fase 2 (carrinho).

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
RSpec + FactoryBot · RuboCop (omakase) · Brakeman · bundler-audit · rails-i18n · dotenv.
Próximas fases: **Stripe** (test mode) · Devise · Pundit.

> **Versões:** escolhidas na fase 1 (estáveis em 29/09/2026) e registradas na lição
> `docs/tutorial/fase-1-catalogo.md`. A versão do Ruby aparece em `.ruby-version` e no
> `Dockerfile`: mude as duas juntas.

## Modelos

- **Vendor** · **Product** (vendor, preço, imagens) · **Inventory** (product, quantidade)
- **Cart** + **CartItem** · **Order** (status: pending|paid|shipped) + **OrderItem**

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
2. Carrinho (sessão em cookie, CSRF, `rate_limit`, preço sempre do banco)
3. **Login do comprador (Devise + Pundit)** + checkout com Stripe em modo teste
   (webhook com assinatura verificada e idempotente). O login veio para antes do checkout por
   decisão do autor: todo pedido nasce com dono (anti-IDOR).
4. Pedidos + estoque (baixa no pagamento confirmado, com `SELECT ... FOR UPDATE`)
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

## Mapa dos arquivos (fase 1)

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
| `spec/` | `lib/` (puras), `models/`, `helpers/`, `requests/` (inclui XSS, SQL injection, CSP). |

**Regras de arquitetura:**
- Lógica pura (sem banco/HTTP/Rails) vai em `lib/`, com teste em `spec/lib/`.
- Toda regra de integridade importante existe no modelo **e** no banco (CHECK/UNIQUE/FK).
- Nada da URL vira estrutura de SQL: valores por placeholder/hash, nomes por allowlist.
- Buscar sempre a partir do escopo permitido (`Product.active.find`, e na fase 3
  `current_user.orders.find`).

## Comandos (bash, no Ubuntu/WSL, dentro de `~/dev/mercadolite`)

```bash
docker compose up -d                 # PostgreSQL 16 de desenvolvimento
bin/rails db:prepare db:seed         # bancos + dados de exemplo
bin/dev                              # servidor + Tailwind (http://localhost:3000)
bundle exec rspec                    # testes
bin/rubocop                          # lint (o CI exige zero ofensas)
bin/brakeman && bin/bundler-audit    # scans de segurança
bin/ci                               # tudo o que o CI roda
```

## Armadilhas conhecidas (descobertas na fase 1)

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
- **`db:prepare` carrega os seeds sempre que CRIA o banco principal, em qualquer ambiente**
  (teste no CI, produção no primeiro deploy via `bin/docker-entrypoint`). Por isso os seeds
  são um *no-op* fora do desenvolvimento (com `return`, nunca `abort`), com teste em
  `spec/db/seeds_spec.rb`.

## Como começar (feito na fase 1)

O esqueleto foi gerado com `rails new . --database=postgresql --css=tailwind --skip-git
--skip-test --skip --skip-kamal --skip-thruster --skip-action-mailbox --skip-action-text
--skip-jbuilder --skip-action-cable` (o porquê de cada opção está na lição da fase 1). CI,
Dependabot, `.env.example`, `docker-compose.yml` (PostgreSQL de dev) e `SECURITY.md` já
existem. Para rodar numa máquina nova, siga a Lição 00.

**Para a fase 3:** use as **chaves de teste** do Stripe no `.env` — nunca as de produção. O
webhook de confirmação de pagamento é o ponto crítico de segurança: valide a assinatura e
trate a idempotência.

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
