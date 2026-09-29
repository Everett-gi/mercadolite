# MercadoLite

Marketplace com catálogo, carrinho, checkout Stripe (modo teste), pedidos e estoque — com o pagamento tratado como ponto crítico de segurança.

> 🚧 **Em construção — fase 2 de 6 concluída (carrinho).** Parte do portfólio
> [Projetos-e-ideias](https://github.com/Everett-gi/Projetos-e-ideias).

![Vitrine do MercadoLite](docs/tutorial/img/fase-1-vitrine-busca.png)

## O que é

Loja/marketplace com produtos, carrinho, **checkout via Stripe (modo teste, gratuito)**,
pedidos com status e controle de estoque.

**Já funciona:**
- **Fase 1:** vitrine com busca sem acento, filtros (vendedor, faixa de preço, em estoque),
  ordenação e paginação; página de produto com imagens (Active Storage) e estoque.
- **Fase 2:** carrinho na sessão (sem login), adicionado via Turbo Stream sem recarregar a
  página, com quantidade e estoque conferidos, preço sempre lido do banco e limpeza diária de
  carrinhos abandonados.

## Stack

Ruby 4.0.7 · Rails 8.1.4 · PostgreSQL 16 · Hotwire (Turbo + Stimulus) · Tailwind CSS ·
Active Storage + libvips · RSpec + FactoryBot · RuboCop · Brakeman · bundler-audit.
Nas próximas fases: **Stripe** (modo teste) · Devise · Pundit.

## Modelos

- ✅ **Vendor** · **Product** (vendedor, preço em centavos, até 5 imagens) · **Inventory** (1:1 com o produto)
- ✅ **Cart** + **CartItem** (de 1 a 10 unidades por linha, sem coluna de preço)
- ⬜ **Order** (status: pending|paid|shipped) + **OrderItem**

## Segurança

Resumo das medidas (detalhes no [`SECURITY.md`](SECURITY.md)):

- Regras críticas **também no banco** (CHECK de preço e estoque, chaves estrangeiras, índices únicos).
- Busca sem SQL injection (placeholders, `sanitize_sql_like`, ordenação por *allowlist*) — com teste.
- Escape de HTML em todas as views + **CSP com nonce** por requisição — um script injetado é bloqueado (verificado no navegador).
- Uploads restritos a JPEG/PNG/WebP (SVG recusado), com limites de tamanho e quantidade.
- Carrinho com **anti-IDOR** (itens procurados só no carrinho da sessão), **CSRF** em três camadas (token, `Origin`, `SameSite`) — um ataque real foi barrado — e **rate limit** (429).
- Sessão em cookie cifrado e autenticado (AES-256-GCM), `HttpOnly`, `SameSite=Lax`, `Secure` em produção.
- Segredos só em variáveis de ambiente; CI bloqueante com Brakeman, bundler-audit e importmap audit; Dependabot.
- O **preço nunca vem do navegador**: o carrinho usa sempre o preço do banco (com teste).
- Próximas fases: **verificação de assinatura** dos webhooks do Stripe, **idempotência** no pagamento e autorização de pedidos (o comprador vê só os seus).

## Rodando localmente

Passo a passo completo (WSL 2 + Ubuntu no Windows 11) na
[Lição 00](docs/tutorial/00-ambiente-wsl.md). Resumo, no terminal do Ubuntu:

```bash
cp .env.example .env            # e defina DATABASE_PASSWORD
docker compose up -d            # PostgreSQL 16
bundle install
bin/rails db:prepare db:seed    # bancos, schema e dados de exemplo
bin/dev                         # http://localhost:3000
```

Testes e verificações (as mesmas do CI):

```bash
bundle exec rspec     # testes
bin/rubocop           # estilo
bin/brakeman          # análise de segurança
bin/bundler-audit     # vulnerabilidades nas gems
bin/ci                # tudo de uma vez
```

## Roadmap

1. ✅ Catálogo (produtos + imagens + busca/filtros)
2. ✅ Carrinho (sessão, CSRF, anti-IDOR, rate limit, Turbo Streams)
3. ⬜ Login do comprador (Devise) + checkout com Stripe em modo teste (webhook assinado e idempotente)
4. ⬜ Pedidos + estoque (baixa no pagamento confirmado)
5. ⬜ Painel do vendedor
6. ⬜ Deploy (Docker Compose + Caddy, ver [`docs/DEPLOY.md`](docs/DEPLOY.md))

## Modo tutorial

Cada fase concluída ganha uma lição em [`docs/tutorial/`](docs/tutorial/):

| Lição | Conteúdo |
|---|---|
| [00 — Ambiente](docs/tutorial/00-ambiente-wsl.md) | WSL 2, Ubuntu, Ruby com mise, Docker Desktop, VS Code |
| [01 — Ruby para quem vem do C/C++](docs/tutorial/01-ruby-para-quem-vem-do-c.md) | objetos, blocos, símbolos, mixins, exceções, Bundler |
| [Fase 1 — Catálogo](docs/tutorial/fase-1-catalogo.md) | Rails, Active Record, migrations e restrições, SQL injection, XSS, CSP, Active Storage, RSpec, CI |
| [Fase 2 — Carrinho](docs/tutorial/fase-2-carrinho.md) | cookies e sessão (AES-256-GCM), CSRF com ataque real, IDOR, rate limiting, Turbo Streams, concerns, jobs com Solid Queue |
