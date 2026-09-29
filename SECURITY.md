# Política de Segurança — MercadoLite

O MercadoLite é um projeto de portfólio: uma loja de demonstração com pagamentos **apenas em
modo de teste** do Stripe. Nenhum produto é vendido de verdade, mas o projeto é construído
como se fosse, porque o objetivo é justamente praticar segurança de aplicações.

## Reportar uma vulnerabilidade

Use o **relato privado de vulnerabilidades** do GitHub: aba **Security → Report a
vulnerability** deste repositório. Por favor, não abra *issues* públicas para falhas de
segurança.

## Gestão de segredos

- Nenhum segredo é versionado: `.env` e `*.key` estão no `.gitignore`, e `.env*` e
  `config/master.key` estão no `.dockerignore`.
- O repositório contém apenas o `.env.example`, com valores fictícios.
- Segredos entram por **variáveis de ambiente**, em tempo de execução, e nunca ficam no
  código nem na imagem Docker. O projeto **não usa** o `config/credentials.yml.enc` do
  Rails: a `SECRET_KEY_BASE` de produção vem do ambiente do servidor.
- O CI usa só credenciais descartáveis (o PostgreSQL de teste morre com o job).
- Recomendado no repositório: *Secret Scanning* e *Push Protection* do GitHub ligados.

## Medidas implementadas

Estado ao fim da **fase 2 (carrinho)**. Referência: OWASP Top 10:2025.

| Risco | Mitigação | Onde |
|---|---|---|
| **A05 — Injection (SQL)** | Acesso ao banco só via Active Record. Valores entram por placeholders/condições com hash, nunca por interpolação; os curingas do `LIKE` são escapados (`sanitize_sql_like`). O `ORDER BY` vem de uma *allowlist* (`ProductSearch::SORTS`), nunca da URL. | `app/models/product.rb`, `app/models/product_search.rb` |
| **A05 — Injection (XSS)** | Todo texto é escapado nas views (`<%= %>`), inclusive a descrição antes do `simple_format`. Nenhum uso de `raw`/`html_safe`. | `app/views/products/` |
| **A05 — Injection (XSS, defesa em profundidade)** | CSP restrita: só `'self'`, com **nonce aleatório por requisição** para scripts e estilos; sem `unsafe-inline`/`unsafe-eval`; `object-src 'none'`, `base-uri`, `form-action` e `frame-ancestors` restritos. Verificado no Chromium: um script injetado é bloqueado. | `config/initializers/content_security_policy.rb` |
| **A06 — Insecure Design (validação de entrada)** | Filtros convertidos para tipos (atributos tipados) e validados: busca com até 100 caracteres, vendedor inteiro positivo, preço em formato estrito (`Brl.parse_cents`), ordenação por *allowlist*. Página prendida ao intervalo válido (sem `OFFSET` arbitrário). *Strong parameters* em todo controller. | `app/models/product_search.rb`, `lib/`, `app/controllers/` |
| **A06 — Insecure Design (integridade dos dados)** | Regras críticas também no banco: `CHECK` de preço (1 centavo a R$ 1 milhão) e de estoque (≥ 0), chaves estrangeiras, índice único de estoque por produto e de nome de vendedor (sem diferenciar maiúsculas). Dinheiro em centavos inteiros, nunca em float. | `db/migrate/` |
| **A06 — Insecure Design (preço e quantidade)** | O navegador envia só produto e quantidade: `cart_items` não tem coluna de preço, e o total usa sempre o preço atual do banco (um `price_cents` forjado é ignorado, com teste). Quantidade por parser estrito (`Quantity.parse`), de 1 a 10 no modelo e por `CHECK` no banco, e nunca acima do estoque. Parâmetros com `params.expect` (malformado → 400). | `app/models/cart_item.rb`, `lib/quantity.rb`, `app/controllers/cart_items_controller.rb` |
| **A06 — Insecure Design (abuso e consumo de recursos)** | `rate_limit` de 30 alterações por minuto por IP no carrinho (429, página em português), com contador no Solid Cache. Visitas (GET) não criam carrinho. Um job diário apaga carrinhos parados há 30 dias. | `app/controllers/cart_items_controller.rb`, `app/jobs/purge_abandoned_carts_job.rb` |
| **A06 — Insecure Design (uploads)** | Imagens: só JPEG/PNG/WebP (tipo detectado pelo conteúdo quando há assinatura), até 5 MB e 5 por produto. **SVG recusado** (pode conter script). | `app/models/product.rb` |
| **A01 — Broken Access Control (IDOR)** | Toda busca por id parte do escopo permitido: `Product.active.find` (inativo → 404) e `current_cart.items.find` (o item de outro carrinho → 404, sem revelar que existe). O carrinho é um recurso singular (`/cart`), sem id na URL. | `app/controllers/products_controller.rb`, `app/controllers/cart_items_controller.rb` |
| **A01 — Broken Access Control (CSRF)** | Toda alteração é POST/PATCH/DELETE com token CSRF (mascarado e por formulário), checagem de `Origin` e cookie `SameSite=Lax`. Um ataque real, vindo de outro site, foi barrado pelas três defesas (422). Há testes com a proteção ligada. GET nunca altera nada. | `app/controllers/`, `config/initializers/session_store.rb`, `spec/requests/cart_spec.rb` |
| **A07 — Authentication Failures (sessão)** | Sessão em cookie cifrado e autenticado (AES-256-GCM, chave derivada da `SECRET_KEY_BASE`): um cookie adulterado é descartado. `HttpOnly`, `SameSite=Lax`, `Secure` em produção e validade de 30 dias. A sessão guarda só o id do carrinho e tokens técnicos. | `config/initializers/session_store.rb` |
| **A02 — Security Misconfiguration** | Cabeçalhos: `Permissions-Policy` (câmera, microfone, geolocalização, pagamento etc. desligados), `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`. Em produção: `force_ssl` (redirecionamento para HTTPS + **HSTS**). Componentes não usados ficaram de fora (Action Cable, Mailbox, Text, Jbuilder). Container de produção roda como usuário **não-root**; o PostgreSQL de desenvolvimento só escuta em `127.0.0.1`. | `config/initializers/security_headers.rb`, `config/environments/production.rb`, `Dockerfile`, `docker-compose.yml` |
| **A03 — Software Supply Chain Failures** | CI bloqueante com `bundler-audit` (gems com CVE conhecida) e `importmap audit` (pacotes JS); Dependabot semanal para gems e GitHub Actions; `Gemfile.lock` versionado. | `.github/` |
| **A08 — Software or Data Integrity Failures** | Token do CI com `permissions: contents: read` (menor privilégio). URLs do Active Storage são assinadas. | `.github/workflows/ci.yml` |
| **A09 — Security Logging and Alerting Failures** | Parâmetros sensíveis (senha, e-mail, token, chaves, CVV...) são filtrados dos logs. | `config/initializers/filter_parameter_logging.rb` |
| **Análise estática** | Brakeman no CI, bloqueante. | `.github/workflows/ci.yml` |

Cada garantia acima tem teste automatizado (`spec/`), incluindo SQL injection, XSS
armazenado, cabeçalhos/CSP e as restrições do banco.

## Limitações conhecidas (fase 1)

- **Sem autenticação ainda.** O carrinho é anônimo, ligado à sessão do navegador. O login
  do comprador (Devise, com `reset_session` no login contra *session fixation*) chega
  **antes do checkout**, na fase 3, junto com a autorização por recurso (Pundit).
- **Sessão em cookie, e não JWT.** A base do portfólio pede JWT onde houver login. O
  MercadoLite é uma aplicação que renderiza HTML no servidor, e para ela o padrão mais seguro
  é a sessão em cookie `HttpOnly`/`Secure`/`SameSite` com proteção CSRF. Um JWT guardado no
  navegador ficaria exposto a roubo por XSS sem trazer ganho. Se um dia houver uma API para
  apps, ela terá autenticação própria por token.
- **Detecção do tipo de imagem.** Arquivos **sem assinatura** (texto puro) renomeados para
  `.png` são aceitos com o tipo declarado. Hoje não há upload pela web, e o `nosniff` impede
  o navegador de reinterpretá-los. A correção (decodificar e regravar a imagem com a libvips,
  o que também remove metadados como o GPS do EXIF) está prevista para a fase 5, e um teste
  `pending` cobra essa correção.
- **Rate limiting por IP** (carrinho): pessoas atrás do mesmo NAT dividem o limite, por isso
  ele é folgado (30 por minuto). O limite do login (fase 3) será mais apertado. Em
  produção, o `remote_ip` depende do Caddy numa rede privada (`X-Forwarded-For` confiável).
  O limite de tamanho do corpo das requisições será configurado no Caddy (fase 6).
- **Estoque não é reservado no carrinho** (decisão de projeto): reservar permitiria
  "sequestrar" o estoque com carrinhos que nunca fecham. A garantia vem na confirmação do
  pagamento (fase 4).
- **LGPD:** não há dados pessoais ainda. O cookie de sessão é estritamente necessário para o
  carrinho e não guarda dados pessoais. Coleta mínima, aceite de termos e exclusão de conta
  entram com o cadastro de usuários.

## Próximas fases (segurança)

| Fase | Medidas |
|---|---|
| 3 — Login + checkout | Devise (senhas com bcrypt), Pundit, **verificação de assinatura do webhook do Stripe**, **idempotência** no processamento do pagamento |
| 4 — Pedidos + estoque | baixa de estoque com trava de linha (`SELECT ... FOR UPDATE`) na confirmação do pagamento |
| 5 — Painel do vendedor | autorização por dono (anti-IDOR), uploads validados pelo conteúdo |
| 6 — Deploy | HTTPS com Caddy, limite de corpo, backups |
