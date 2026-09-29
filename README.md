# MercadoLite

Marketplace com catálogo, carrinho, checkout Stripe (modo teste), pedidos e estoque — com o pagamento tratado como ponto crítico de segurança.

> 📋 **Em construção.** O blueprint está pronto e a implementação começa pela fase 1 do
> roadmap abaixo. Parte do portfólio
> [Projetos-e-ideias](https://github.com/Everett-gi/Projetos-e-ideias).

## O que é

Loja/marketplace com produtos, carrinho, **checkout via Stripe (modo teste, gratuito)**,
pedidos com status e controle de estoque.

## Stack (planejada)

Ruby 3.3 · Rails 8 · **Stripe** (test mode) · Devise · Pundit · Active Storage ·
PostgreSQL 16 · RSpec · RuboCop · Brakeman.

## Modelos (planejado)

- **Vendor** · **Product** (vendor, preço, imagens) · **Inventory** (product, quantidade)
- **Cart** + **CartItem** · **Order** (status: pending|paid|shipped) + **OrderItem**

## Funcionalidades principais

- Catálogo com busca/filtros · carrinho · checkout Stripe (teste)
- Pedidos e mudança de status · estoque · painel do vendedor

## Segurança

**Verificação de assinatura** dos webhooks do Stripe; **idempotência** no processamento de
pagamento; autorização de pedidos (comprador vê os seus); **validação de preço no servidor**
(nunca confiar no valor vindo do cliente).

## Roadmap

1. Catálogo (produtos + imagens)
2. Carrinho
3. Checkout com Stripe em modo teste
4. Pedidos + estoque (baixa no pagamento confirmado)
5. Painel do vendedor + autenticação
6. Deploy

---

Desenvolvido em modo tutorial: cada fase concluída ganha uma lição em `docs/tutorial/`.
