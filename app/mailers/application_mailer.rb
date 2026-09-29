# Base de todos os e-mails da loja, inclusive os do Devise (config.parent_mailer).
class ApplicationMailer < ActionMailer::Base
  # O remetente vem do ambiente: em produção, um endereço do domínio da loja, autorizado no
  # provedor de e-mail (SPF/DKIM), senão os e-mails caem no spam.
  default from: ENV.fetch("MAILER_FROM", "MercadoLite <nao-responda@mercadolite.test>")
  layout "mailer"
end
