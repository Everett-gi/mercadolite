# Devolve ao comprador o dinheiro de um pedido pago que não pôde ser atendido (o estoque
# acabou entre o checkout e a confirmação do pagamento).
#
# Enfileirado por Order#confirm_payment! depois do COMMIT, e de novo pela conciliação
# (ReconcileOrdersJob) se o pedido ficar parado em "refunding".
class RefundOrderJob < ApplicationJob
  queue_as :default

  # Falhas passageiras (rede, limite de requisições, instabilidade do Stripe): tenta de novo,
  # esperando cada vez mais. Repetir é seguro: a chave de idempotência faz o Stripe devolver o
  # MESMO estorno. Outros erros (chave sem permissão, pagamento já estornado) não se resolvem
  # sozinhos: o job falha, o erro vai para o log e a conciliação tenta de novo mais tarde.
  retry_on Stripe::APIConnectionError, Stripe::RateLimitError, Stripe::APIError,
           wait: :polynomially_longer, attempts: 5

  # @param order [Order]
  def perform(order)
    return unless order.refunding?

    refund = StripeRefunds.new.refund_in_full(order)
    result = order.record_refund!(refund)
    level = result == :refund_not_accepted ? :error : :info
    Rails.logger.public_send(level, "[estorno] pedido #{order.id}: #{result} (#{refund.status})")
  end
end
