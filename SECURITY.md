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

Estado ao fim da **fase 3b (checkout com Stripe)**. Referência: OWASP Top 10:2025.

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
| **A01 — Broken Access Control (IDOR)** | Toda busca por id parte do escopo permitido: `Product.active.find` (inativo → 404) e `current_cart.items.find` (o item de outro carrinho → 404, sem revelar que existe). O carrinho é um recurso singular (`/cart`), sem id na URL. Logado, o carrinho é o da conta; visitante, só um carrinho **sem dono** (`Cart.guest`): uma cópia antiga do cookie de visitante não alcança o carrinho reivindicado no login. Teste de IDOR entre duas contas. | `app/controllers/products_controller.rb`, `app/controllers/cart_items_controller.rb`, `app/controllers/concerns/current_cart.rb` |
| **A01 — Broken Access Control (pedidos)** | Autorização com **Pundit**: `OrderPolicy` (o comprador vê e paga só os próprios pedidos; o que não foi liberado é proibido) e `policy_scope` em toda busca de pedido, inclusive a da volta do Stripe (`session_id` de outra pessoa → 404, sem consultar o Stripe). `verify_authorized`/`verify_policy_scoped` quebram a ação que esquecer de autorizar. Negação responde 404, sem revelar que o pedido existe. | `app/policies/`, `app/controllers/orders_controller.rb`, `app/controllers/checkouts_controller.rb` |
| **A01 — Broken Access Control (CSRF)** | Toda alteração é POST/PATCH/DELETE com token CSRF (mascarado e por formulário), checagem de `Origin` e cookie `SameSite=Lax`. Um ataque real, vindo de outro site, foi barrado pelas três defesas (422). O login também exige o token (contra *login CSRF*), e o token da sessão é trocado ao entrar: um token de antes do login não vale depois. "Sair" é DELETE. Há testes com a proteção ligada. GET nunca altera nada. | `app/controllers/`, `config/initializers/session_store.rb`, `spec/requests/cart_spec.rb`, `spec/requests/auth_spec.rb` |
| **A06 — Insecure Design (pagamento)** | **Preço sempre do servidor:** o pedido nasce do carrinho com nome e preço lidos do banco e **congelados** em `order_items`; os itens enviados ao Stripe saem do pedido (parâmetros forjados são ignorados, com teste). **Quem confirma o pagamento é só o Stripe:** o webhook assinado ou a consulta à API; a URL de retorno não prova nada. Na confirmação, a sessão, o status "paid", o **valor** e a **moeda** precisam bater com o pedido (divergência → não confirma e registra erro). Só cartão (sem pagamento assíncrono). Página de pagamento expira em 30 minutos (pedido cancelado pelo webhook). Checkout com `rate_limit` por conta. | `app/models/order.rb`, `app/models/stripe_checkout.rb`, `app/controllers/checkouts_controller.rb` |
| **A08 — Integridade (webhooks do Stripe)** | Assinatura **HMAC-SHA256** do corpo cru conferida (`Stripe::Webhook.construct_event`, comparação em tempo constante); evento com mais de **5 minutos** recusado (contra *replay*); corpo acima de **64 KB** recusado (413) antes de qualquer processamento; sem sessão nem cookie (controller de API). **Idempotência em duas camadas:** cada evento é gravado uma vez só (índice único em `stripe_events.event_id`, na mesma transação do efeito: se o efeito falhar, o registro some e o Stripe reenvia) e a transição de status usa trava de linha (`with_lock`, `SELECT ... FOR UPDATE`). Testado com duas conexões reais ao banco: uma confirmação ou um cancelamento que chega enquanto outra confirmação trava o pedido espera por ela e não muda o pedido pago (sem a trava, o cancelamento cancelava um pedido pago). | `app/controllers/stripe_webhooks_controller.rb`, `app/models/stripe_event.rb`, `app/models/order.rb` |
| **A07 — Authentication Failures (senhas)** | Devise com **bcrypt** de custo 12 (~250 ms por hash); a senha nunca é guardada. Senha de **15 a 72 caracteres** (NIST SP 800-63B-4), limitada também a **72 bytes** (o bcrypt ignora o resto em silêncio); sem regras de composição; senhas previsíveis recusadas (repetitivas, com o nome da loja ou com o e-mail). | `app/models/user.rb`, `lib/password_policy.rb`, `config/initializers/devise.rb` |
| **A07 — Authentication Failures (sessão)** | Sessão em cookie cifrado e autenticado (AES-256-GCM, chave derivada da `SECRET_KEY_BASE`): um cookie adulterado é descartado. `HttpOnly`, `SameSite=Lax`, `Secure` em produção. O login grava id + "sal" no cookie; o sal inclui um `session_token` trocado a cada logout, então **"Sair" invalida todas as cópias do cookie** (em todos os aparelhos). Trocar a senha derruba as outras sessões. Sessão parada por **2 horas** expira (e também invalida as cópias). *Session fixation*: o login vai para um cookie novo; a cópia de antes continua de visitante (testado). | `config/initializers/session_store.rb`, `app/models/user.rb`, `config/initializers/warden_hooks.rb` |
| **A07 — Authentication Failures (enumeração)** | Modo paranoico do Devise: login, "esqueci a senha" e reenvio da confirmação respondem igual exista ou não a conta, e o login com e-mail inexistente calcula o mesmo número de hashes bcrypt (tempo de resposta igual; testado contando as chamadas). E-mails enviados por job, fora da requisição. | `config/initializers/devise.rb`, `app/models/user.rb`, `spec/requests/auth_spec.rb` |
| **A07 — Authentication Failures (força bruta)** | `rate_limit` no login por IP (10 a cada 3 min) **e por e-mail** (5 a cada 15 min, contra ataque distribuído a uma conta), com o e-mail reduzido a SHA-256 na chave do contador. Limites também no cadastro, no "esqueci a senha" e no reenvio da confirmação (3 por hora por e-mail, contra bombardeio de e-mails) e na edição/exclusão da conta. Sem `lockable`, que permitiria travar a conta dos outros. | `app/controllers/users/`, `app/controllers/concerns/email_rate_limit.rb` |
| **A07 — Authentication Failures (recuperação e confirmação)** | Conta só entra depois de confirmar o e-mail (link válido por 3 dias). Redefinição de senha com token aleatório de **1 hora**, uso único, guardado no banco como HMAC. Aviso por e-mail quando o e-mail ou a senha mudam. Links com host fixo (`APP_HOST`), nunca derivado do cabeçalho `Host`. | `config/initializers/devise.rb`, `config/environments/production.rb` |
| **A02 — Security Misconfiguration (chaves do Stripe)** | Só **chaves de teste**: a aplicação **não sobe** com `sk_live_`/`rk_live_` (a loja nunca cobra de verdade). Recomendada a chave **restrita** (`rk_test_`) com o mínimo de permissões. Chamadas à API com tempo máximo (5 s para conectar, 20 s para ler) e novas tentativas com **chave de idempotência** (uma por pedido: um clique duplo não cria duas sessões). Nos testes, **WebMock** bloqueia qualquer acesso à rede. | `config/initializers/stripe.rb`, `lib/stripe_keys.rb`, `spec/rails_helper.rb` |
| **A02 — Security Misconfiguration** | Cabeçalhos: `Permissions-Policy` (câmera, microfone, geolocalização, pagamento etc. desligados), `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`. Em produção: `force_ssl` (redirecionamento para HTTPS + **HSTS**). Componentes não usados ficaram de fora (Action Cable, Mailbox, Text, Jbuilder). Container de produção roda como usuário **não-root**; o PostgreSQL de desenvolvimento só escuta em `127.0.0.1`. | `config/initializers/security_headers.rb`, `config/environments/production.rb`, `Dockerfile`, `docker-compose.yml` |
| **A03 — Software Supply Chain Failures** | CI bloqueante com `bundler-audit` (gems com CVE conhecida) e `importmap audit` (pacotes JS); Dependabot semanal para gems e GitHub Actions; `Gemfile.lock` versionado. Toda gem usada diretamente é declarada no `Gemfile` (ex.: `ruby-vips`), e um teste exercita o processamento de imagem de verdade. Assim, uma atualização que tire uma dependência do bundle quebra o CI, e não a produção. `image_processing` 2.1 (correções de RCE e *loaders* sem fuzzing bloqueados). | `.github/`, `Gemfile`, `spec/models/product_spec.rb` |
| **A08 — Software or Data Integrity Failures** | Token do CI com `permissions: contents: read` (menor privilégio). URLs do Active Storage são assinadas. | `.github/workflows/ci.yml` |
| **A09 — Security Logging and Alerting Failures** | Parâmetros sensíveis (senha, e-mail, token, chaves, CVV...) são filtrados dos logs. Os jobs de e-mail **não registram argumentos** no log: o token do link de redefinição ia parar lá pelo Active Job (achado e corrigido na fase 3a, com teste). O conteúdo dos **eventos do Stripe** (chave `data`, com nome, e-mail e endereço do comprador) também é filtrado: o Rails escrevia o corpo inteiro do webhook no log (achado no teste real da fase 3b, com teste). Os registros próprios do pagamento levam só ids e resultados. Produção em nível `info` (em `debug`, o corpo dos e-mails iria para o log). | `config/initializers/filter_parameter_logging.rb`, `config/initializers/action_mailer.rb` |
| **LGPD** | Coleta mínima (e-mail e hash da senha; sem nome, CPF ou histórico de IPs). Aceite dos Termos de Uso e da Política de Privacidade obrigatório no cadastro, com data gravada. Exclusão da conta pelo próprio titular (exige a senha), apagando e-mail, senha e carrinho; os **pedidos ficam como registro da venda, mas sem dono** (`ON DELETE SET NULL`, sem dado pessoal). Ao Stripe vai só o e-mail (para o recibo) e os itens; o cartão é digitado na página do Stripe e nunca passa pelo servidor. `stripe_events` guarda só id e tipo do evento. Contas nunca confirmadas são apagadas em 7 dias. Páginas `/terms` e `/privacy`. | `app/models/user.rb`, `app/controllers/users/registrations_controller.rb`, `app/jobs/purge_unconfirmed_users_job.rb`, `app/views/pages/` |
| **Análise estática** | Brakeman no CI, bloqueante. | `.github/workflows/ci.yml` |

Cada garantia acima tem teste automatizado (`spec/`), incluindo SQL injection, XSS
armazenado, cabeçalhos/CSP, as restrições do banco, cookie copiado depois do logout,
enumeração, rate limit, assinatura e idade dos webhooks, idempotência (inclusive com duas
conexões concorrentes), valor divergente e IDOR nos pedidos. Os testes de segurança foram
vistos falhando com a proteção removida.

## Limitações conhecidas

- **O cadastro ainda revela se um e-mail tem conta** ("E-mail já está em uso"). O rate limit
  de cadastro (5 a cada 15 minutos por IP) deixa a enumeração em massa lenta. A correção
  (responder sempre "enviamos um e-mail" e avisar o dono da conta existente) está planejada.
- **O limite por e-mail pode ser usado para atrapalhar alguém:** errando a senha de uma conta
  5 vezes, um atacante bloqueia as tentativas de login dela por até 15 minutos. É o preço de
  segurar ataques distribuídos sem o `lockable` (que trancaria a conta).
- **Sem segundo fator (MFA/passkeys)** e sem conferência da senha contra listas de senhas
  vazadas (como o *Pwned Passwords*). Os dois são melhorias futuras.
- **"Sair" encerra todas as sessões da conta**, em todos os aparelhos (o `session_token` é
  por conta, não por aparelho).
- **Sessão sem prazo absoluto:** expira com 2 horas de inatividade, mas quem usa a loja
  continuamente continua logado.
- **Tokens na fila de jobs:** o token do link de redefinição fica nos argumentos do job no
  banco do Solid Queue até o job ser limpo (a limpeza roda a cada hora). O token de
  confirmação fica no banco como está (o de redefinição, só como HMAC).
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
- **Rate limiting por IP:** pessoas atrás do mesmo NAT dividem os limites (o do carrinho é
  folgado, 30 por minuto; o do login, 10 a cada 3 minutos). Em produção, o `remote_ip`
  depende do Caddy numa rede privada (`X-Forwarded-For` confiável). O limite de tamanho do
  corpo das requisições será configurado no Caddy (fase 6).
- **Estoque não é reservado no carrinho** (decisão de projeto): reservar permitiria
  "sequestrar" o estoque com carrinhos que nunca fecham. O checkout confere o estoque, mas
  **ainda não dá baixa** no pagamento: dois compradores podem pagar pela última unidade. A
  baixa com trava de linha na confirmação do pagamento é a fase 4.
- **Pedido pendente sem webhook:** se o webhook não chegar (em desenvolvimento, sem o
  `stripe listen`), o pedido fica "aguardando pagamento" até alguém abrir a volta do Stripe,
  que consulta a API. Uma rotina de conciliação (consultar os pendentes antigos) fica para a
  fase 4.
- **Número do pedido sequencial:** o id aparece na tela ("Pedido nº 42") e revela o volume de
  vendas. O acesso é protegido (404 para quem não é o dono), mas o número em si não é segredo.
- **LGPD:** o prazo de guarda dos logs do servidor (que têm IPs) será definido no deploy
  (fase 6). O cookie de sessão é estritamente necessário (carrinho, login e CSRF) e não guarda
  dados pessoais além do id da conta.

## Próximas fases (segurança)

| Fase | Medidas |
|---|---|
| 4 — Pedidos + estoque | baixa de estoque com trava de linha (`SELECT ... FOR UPDATE`) na confirmação do pagamento |
| 5 — Painel do vendedor | autorização por dono (anti-IDOR), uploads validados pelo conteúdo |
| 6 — Deploy | HTTPS com Caddy, limite de corpo, backups |
