# MercadoLite — Contexto do Projeto

> Handoff para o Claude Code. Este arquivo é **autossuficiente**: traz o blueprint do projeto e,
> no fim, a base de segurança e as convenções do portfólio. A central do portfólio é
> [Everett-gi/Projetos-e-ideias](https://github.com/Everett-gi/Projetos-e-ideias). Referências de qualidade:
> [DocSage](https://github.com/Everett-gi/docsage) e [PwnCheck](https://github.com/Everett-gi/pwncheck)
> (estrutura, testes, CI e as lições do modo tutorial).
> **Status:** 📋 blueprint pronto — a construção começa pela fase 1.

## Modo tutorial

O autor programa bem em **C e C++** (lógica, ponteiros, memória, compilação) e
está aprendendo Python; **Ruby e Rails são novos para ele** — este projeto também é o curso de Ruby.

- Explique cada passo e o **porquê**, com analogias a C/C++ quando ajudarem (ex.: tudo é objeto e a tipagem é dinâmica, blocos × lambdas do C++, módulos e mixins × herança múltipla, Bundler e gems × gerenciador de pacotes, a "convenção sobre configuração" do Rails, Active Record × SQL escrito à mão).
  Não explique lógica de programação básica; foque no que é novo.
- Cada fase concluída ganha uma lição em `docs/tutorial/fase-N-<tema>.md`, com exercícios e
  respostas no fim — o modelo são as lições do PwnCheck.
- Confirme rodando código qualquer afirmação técnica antes de escrevê-la numa lição.
- Sessões na nuvem rodam em Linux (bash). Ao indicar comandos para o autor rodar na máquina
  dele, use PowerShell (Windows 11, VS Code, repositórios clonados em `C:\dev`).
- Commits no padrão Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `ci:`, `chore:`),
  um assunto por commit. Rode lint e testes sobre o estado final, logo antes de cada commit.

## Prioridades

**1) Segurança · 2) Clareza do código · 3) Funcionalidade.** Nessa ordem.

## O que é

Loja/marketplace com produtos, carrinho, **checkout via Stripe (modo teste, gratuito)**,
pedidos com status e controle de estoque. Bom candidato a carro-chefe de Ruby.

**Valor de portfólio:** fluxo de pagamento e estado de pedido "vendem" muito bem.

## Stack

Ruby 3.3 · Rails 8 · **Stripe** (test mode) · Devise · Pundit · Active Storage ·
PostgreSQL 16 · RSpec · RuboCop · Brakeman.

> **Versões:** o blueprint cita Ruby 3.3 e Rails 8. No scaffold, use as versões estáveis atuais
> (confira em ruby-lang.org e rubyonrails.org) e registre a escolha na lição da fase 1.

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

1. Catálogo (produtos + imagens)
2. Carrinho
3. Checkout com Stripe em modo teste
4. Pedidos + estoque (baixa no pagamento confirmado)
5. Painel do vendedor + autenticação
6. Deploy (ver `docs/DEPLOY.md`)

## Como começar

1. Dentro deste repositório:
   `rails new . --database=postgresql --css=tailwind --skip-git --skip-test --skip`.
   `--skip-git` porque o repositório já existe; `--skip-test` porque o portfólio usa
   RSpec (adicione `rspec-rails`); `--skip` preserva os arquivos que já estão aqui
   (`README.md`, `CLAUDE.md`, `.gitignore`, `.gitattributes`). Depois, junte ao nosso
   `.gitignore` o que o Rails costuma ignorar e estiver faltando.
2. Já na fase 1: CI em `.github/workflows/ci.yml` com RSpec, RuboCop, Brakeman e
   bundler-audit (se o `rails new` gerar um workflow, adapte-o) e um `.env.example`
   com valores fictícios. O deploy do portfólio usa Docker Compose + Caddy
   (`docs/DEPLOY.md`); o `Dockerfile` gerado pelo Rails pode ser aproveitado.
3. Use as **chaves de teste** do Stripe no `.env` — nunca as de produção. O webhook de
   confirmação de pagamento é o ponto crítico de segurança: valide a assinatura e
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
