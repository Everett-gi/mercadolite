# O Active Job escreve no log os argumentos de cada job, ao enfileirar e ao executar. Nos
# e-mails do Devise, um desses argumentos é o TOKEN do link (de redefinição de senha ou de
# confirmação): quem lesse os logs poderia trocar a senha de qualquer conta. Por isso, os
# jobs de e-mail não registram argumentos.
#
# on_load: espera o Action Mailer ser carregado (o Rails carrega tudo sob demanda).
ActiveSupport.on_load(:action_mailer) do
  ActionMailer::MailDeliveryJob.log_arguments = false
end
