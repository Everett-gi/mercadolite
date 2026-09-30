# Conciliação: confere com o Stripe os pedidos que ficaram para trás. Roda a cada 15 minutos
# (config/recurring.yml).
#
# - Pendente há mais de STALE_AFTER: o webhook não chegou (perdido, ou o "stripe listen"
#   estava desligado). A página de pagamento já expirou (30 min), então o Stripe sabe como a
#   sessão terminou: paga → confirma (com baixa de estoque); expirada → cancela.
#   NUNCA cancela sem perguntar: um pedido PAGO cujo webhook atrasou seria cancelado, e o
#   webhook, quando chegasse, encontraria o pedido fora de "pending" e não faria nada.
# - Pendente sem sessão (o processo caiu antes de criar a sessão no Stripe): cancela.
# - Pendente há mais de GIVE_UP_AFTER: sai da conciliação (veja a constante).
# - Em "refunding" há mais de STALE_AFTER: o RefundOrderJob esgotou as tentativas; tenta de
#   novo. A chave de idempotência e o próprio Stripe (que não estorna mais que o valor pago)
#   impedem um estorno em dobro.
class ReconcileOrdersJob < ApplicationJob
  queue_as :default

  STALE_AFTER = 1.hour
  # Uma sessão de pagamento vive no máximo 24 horas no Stripe: depois disso, a consulta dá
  # sempre a mesma resposta. Pedido que continua pendente depois de 3 dias só pode ser um erro
  # que se repete (por exemplo, a sessão é de outra conta do Stripe, depois de uma troca de
  # chaves) e precisa de uma pessoa para olhar; a conciliação para de consultá-lo.
  GIVE_UP_AFTER = 3.days
  BATCH_SIZE = 100

  # @return [Hash{Symbol => Integer}] quantos pedidos terminaram em cada resultado
  def perform
    return {} unless StripeCheckout.configured?

    results = Hash.new(0)
    checkout = StripeCheckout.new
    # Do mais novo para o mais antigo: pedidos que dão erro em toda rodada não ocupam o lote
    # para sempre (achado no teste com o Stripe de verdade).
    Order.pending.where(created_at: GIVE_UP_AFTER.ago...STALE_AFTER.ago)
         .order(created_at: :desc).limit(BATCH_SIZE).each do |order|
      results[reconcile(order, checkout)] += 1
    end
    Order.refunding.where(paid_at: ...STALE_AFTER.ago).order(:id).limit(BATCH_SIZE).each do |order|
      RefundOrderJob.perform_later(order)
      results[:refund_retried] += 1
    end

    Rails.logger.info("[conciliação] #{results}") if results.any?
    results.to_h
  end

  private

  # @return [Symbol]
  def reconcile(order, checkout)
    return order.cancel_unstarted! if order.stripe_checkout_session_id.nil?

    checkout.sync(order)
  rescue Stripe::StripeError => e
    # Um pedido com problema não impede os outros; ele volta na próxima rodada.
    Rails.logger.warn("[conciliação] pedido #{order.id}: #{e.class}")
    :stripe_error
  end
end
