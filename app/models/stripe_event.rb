# Um evento de webhook do Stripe que já foi processado. Serve para processar cada evento
# UMA vez só: o Stripe reenvia o evento se não receber resposta a tempo, e pode entregar o
# mesmo evento duas vezes, até ao mesmo tempo.
#
# Não guarda o conteúdo do evento (nem dado pessoal): só o id e o tipo.
class StripeEvent < ApplicationRecord
  # O que fazer com cada tipo de evento. Os demais são ignorados (e respondidos com 200).
  PAYMENT_CONFIRMED = %w[checkout.session.completed checkout.session.async_payment_succeeded].freeze
  PAYMENT_ABANDONED = %w[checkout.session.expired checkout.session.async_payment_failed].freeze

  # Processa o evento, se ainda não foi processado.
  #
  # O registro do evento e o efeito dele (pagar ou cancelar o pedido) acontecem na MESMA
  # transação. Se o efeito falhar, o registro some junto (rollback) e o Stripe pode reenviar.
  # Se o registro viesse antes, numa transação separada, uma falha no meio perderia o evento
  # para sempre.
  #
  # @param event [Stripe::Event] já com a assinatura conferida
  # @return [Symbol] :duplicate, :ignored, :order_not_found ou o resultado do pedido
  def self.process(event)
    transaction do
      create!(event_id: event.id, event_type: event.type)
      apply(event)
    end
  rescue ActiveRecord::RecordNotUnique
    # Outro processo já registrou este evento (o índice único barrou este).
    :duplicate
  end

  # @return [Symbol]
  def self.apply(event)
    confirm = PAYMENT_CONFIRMED.include?(event.type)
    return :ignored unless confirm || PAYMENT_ABANDONED.include?(event.type)

    session = event.data.object
    order = Order.find_by(stripe_checkout_session_id: session.id)
    return :order_not_found if order.nil?

    confirm ? order.confirm_payment!(session) : order.cancel_checkout!(session)
  end
  private_class_method :apply
end
