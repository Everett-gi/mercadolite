# Apaga os carrinhos sem nenhuma alteração há mais de Cart::ABANDONED_AFTER (30 dias).
#
# Por quê: cada visitante que coloca algo no carrinho cria uma linha no banco. Sem limpeza,
# carrinhos esquecidos (e os criados por robôs) cresceriam para sempre. Roda todo dia pelo
# Solid Queue (config/recurring.yml).
class PurgeAbandonedCartsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 1_000

  # @return [Integer] quantos carrinhos foram apagados
  def perform
    # Em lotes: DELETEs pequenos não travam a tabela por muito tempo. Os itens vão junto,
    # pelo ON DELETE CASCADE da chave estrangeira (sem carregar nada na memória do Ruby).
    Cart.abandoned.in_batches(of: BATCH_SIZE).delete_all
  end
end
