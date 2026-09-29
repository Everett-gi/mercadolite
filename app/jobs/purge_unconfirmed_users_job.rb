# Apaga as contas que nunca confirmaram o e-mail, criadas há mais de
# User::UNCONFIRMED_EXPIRES_AFTER (7 dias). Roda todo dia pelo Solid Queue
# (config/recurring.yml).
#
# Por quê (LGPD, coleta mínima): uma conta sem confirmação guarda o e-mail de alguém que
# talvez nunca tenha pedido cadastro. E, sem limpeza, quem cadastrasse o e-mail de outra
# pessoa impediria o dono verdadeiro de criar a conta dele.
class PurgeUnconfirmedUsersJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 1_000

  # @return [Integer] quantas contas foram apagadas
  def perform
    # delete_all não roda callbacks do Ruby; o carrinho da conta vai junto pelo
    # ON DELETE CASCADE da chave estrangeira carts.user_id.
    User.expired_unconfirmed.in_batches(of: BATCH_SIZE).delete_all
  end
end
