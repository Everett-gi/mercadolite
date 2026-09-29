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

Estado ao fim da **fase 1 (catálogo)**. Referência: OWASP Top 10:2025.

| Risco | Mitigação | Onde |
|---|---|---|
| **A05 — Injection (SQL)** | Acesso ao banco só via Active Record. Valores entram por placeholders/condições com hash, nunca por interpolação; os curingas do `LIKE` são escapados (`sanitize_sql_like`). O `ORDER BY` vem de uma *allowlist* (`ProductSearch::SORTS`), nunca da URL. | `app/models/product.rb`, `app/models/product_search.rb` |
| **A05 — Injection (XSS)** | Todo texto é escapado nas views (`<%= %>`), inclusive a descrição antes do `simple_format`. Nenhum uso de `raw`/`html_safe`. | `app/views/products/` |
| **A05 — Injection (XSS, defesa em profundidade)** | CSP restrita: só `'self'`, com **nonce aleatório por requisição** para scripts e estilos; sem `unsafe-inline`/`unsafe-eval`; `object-src 'none'`, `base-uri`, `form-action` e `frame-ancestors` restritos. Verificado no Chromium: um script injetado é bloqueado. | `config/initializers/content_security_policy.rb` |
| **A06 — Insecure Design (validação de entrada)** | Filtros convertidos para tipos (atributos tipados) e validados: busca com até 100 caracteres, vendedor inteiro positivo, preço em formato estrito (`Brl.parse_cents`), ordenação por *allowlist*. Página prendida ao intervalo válido (sem `OFFSET` arbitrário). *Strong parameters* em todo controller. | `app/models/product_search.rb`, `lib/`, `app/controllers/` |
| **A06 — Insecure Design (integridade dos dados)** | Regras críticas também no banco: `CHECK` de preço (1 centavo a R$ 1 milhão) e de estoque (≥ 0), chaves estrangeiras, índice único de estoque por produto e de nome de vendedor (sem diferenciar maiúsculas). Dinheiro em centavos inteiros, nunca em float. | `db/migrate/` |
| **A06 — Insecure Design (uploads)** | Imagens: só JPEG/PNG/WebP (tipo detectado pelo conteúdo quando há assinatura), até 5 MB e 5 por produto. **SVG recusado** (pode conter script). | `app/models/product.rb` |
| **A01 — Broken Access Control** | Produtos inativos respondem 404, igual a um id inexistente (buscar sempre a partir do escopo permitido). Ainda não há usuários nem áreas restritas (veja "Limitações"). | `app/controllers/products_controller.rb` |
| **A02 — Security Misconfiguration** | Cabeçalhos: `Permissions-Policy` (câmera, microfone, geolocalização, pagamento etc. desligados), `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`. Em produção: `force_ssl` (redirecionamento para HTTPS + **HSTS**). Componentes não usados ficaram de fora (Action Cable, Mailbox, Text, Jbuilder). Container de produção roda como usuário **não-root**; o PostgreSQL de desenvolvimento só escuta em `127.0.0.1`. | `config/initializers/security_headers.rb`, `config/environments/production.rb`, `Dockerfile`, `docker-compose.yml` |
| **A03 — Software Supply Chain Failures** | CI bloqueante com `bundler-audit` (gems com CVE conhecida) e `importmap audit` (pacotes JS); Dependabot semanal para gems e GitHub Actions; `Gemfile.lock` versionado. | `.github/` |
| **A08 — Software or Data Integrity Failures** | Token do CI com `permissions: contents: read` (menor privilégio). URLs do Active Storage são assinadas. | `.github/workflows/ci.yml` |
| **A09 — Security Logging and Alerting Failures** | Parâmetros sensíveis (senha, e-mail, token, chaves, CVV...) são filtrados dos logs. | `config/initializers/filter_parameter_logging.rb` |
| **Análise estática** | Brakeman no CI, bloqueante. | `.github/workflows/ci.yml` |

Cada garantia acima tem teste automatizado (`spec/`), incluindo SQL injection, XSS
armazenado, cabeçalhos/CSP e as restrições do banco.

## Limitações conhecidas (fase 1)

- **Sem autenticação ainda.** Não há login, carrinho nem pedidos; a aplicação só expõe a
  vitrine pública (leitura). O login do comprador (Devise, sessão em cookie) chega **antes
  do checkout**, na fase 3, junto com a autorização por recurso (Pundit, anti-IDOR).
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
- **Rate limiting** ainda não está ativo: entra com o carrinho (fase 2) e o login (fase 3),
  usando o `rate_limit` do Rails 8. O limite de tamanho do corpo das requisições será
  configurado no Caddy, no deploy (fase 6).
- **LGPD:** a fase 1 não coleta dados pessoais. Coleta mínima, aceite de termos e exclusão
  de conta entram com o cadastro de usuários.

## Próximas fases (segurança)

| Fase | Medidas |
|---|---|
| 2 — Carrinho | CSRF nos formulários, `rate_limit`, preço sempre lido do banco |
| 3 — Login + checkout | Devise (senhas com bcrypt), Pundit, **verificação de assinatura do webhook do Stripe**, **idempotência** no processamento do pagamento |
| 4 — Pedidos + estoque | baixa de estoque com trava de linha (`SELECT ... FOR UPDATE`) na confirmação do pagamento |
| 5 — Painel do vendedor | autorização por dono (anti-IDOR), uploads validados pelo conteúdo |
| 6 — Deploy | HTTPS com Caddy, limite de corpo, backups |
