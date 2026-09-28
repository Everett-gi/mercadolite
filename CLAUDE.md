# MercadoLite — Contexto do Projeto

> Handoff para o Claude Code. Convenções compartilhadas em `../../README.md`.
> **Status:** blueprint (a construir). Referência de qualidade: `../../python/docsage`.

## O que é
Loja/marketplace com produtos, carrinho, **checkout via Stripe (modo teste, gratuito)**,
pedidos com status e controle de estoque. Bom candidato a carro-chefe de Ruby.

**Valor de portfólio:** fluxo de pagamento e estado de pedido "vendem" muito bem.

## Stack
Ruby 3.3 · Rails 8 · **Stripe** (test mode) · Devise · Pundit · Active Storage ·
PostgreSQL 16 · RSpec · RuboCop · Brakeman.

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
6. Deploy (ver `../../DEPLOY-GERAL.md` — notas de Rails)

## Como começar
Scaffold: `rails new mercadolite --database=postgresql --css=tailwind`. Use as **chaves de
teste** do Stripe no `.env`. O webhook de confirmação de pagamento é o ponto crítico de
segurança — valide a assinatura e trate idempotência.
