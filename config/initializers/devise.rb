# Configuração do Devise (autenticação). O gerador cria um arquivo de 300 linhas com todas
# as opções comentadas; aqui ficam só as que usamos, cada uma com o porquê. A lista completa
# está no próprio gem: bundle exec gem contents devise | grep templates/devise.rb
Devise.setup do |config|
  require "devise/orm/active_record"

  # Os e-mails do Devise herdam do ApplicationMailer: mesmo remetente e mesmo layout.
  config.parent_mailer = "ApplicationMailer"
  # Procura as telas e os e-mails em app/views/users/ (as nossas, em português) antes das
  # telas padrão que vêm dentro do gem.
  config.scoped_views = true

  # "Joana@Exemplo.com " e "joana@exemplo.com" são a mesma conta.
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]

  # Modo paranoico: login, "esqueci a senha" e "reenviar confirmação" respondem a MESMA
  # mensagem exista ou não o e-mail na base. Sem isso, qualquer um descobriria quem tem conta
  # (enumeração de usuários). No login, a senha é "hasheada" mesmo quando o e-mail não existe,
  # para que o tempo de resposta também não denuncie.
  config.paranoid = true

  # Custo do bcrypt: cada +1 dobra o tempo do hash (e o de quem tenta adivinhar a senha).
  # 12 leva ~250 ms por tentativa. Nos testes, 1, para a suíte não ficar lenta.
  config.stretches = Rails.env.test? ? 1 : 12

  # Senha: de 15 caracteres (NIST SP 800-63B-4 para senha como único fator) a 72 (o limite
  # do bcrypt; o modelo User confere também os 72 BYTES, por causa dos acentos).
  config.password_length = 15..72

  # Trocar o e-mail exige confirmar o novo endereço; até lá, vale o antigo.
  config.reconfirmable = true
  # O link de confirmação vence em 3 dias; o de redefinir senha, em 1 hora.
  config.confirm_within = 3.days
  config.reset_password_within = 1.hour

  # Avisa o dono da conta, no e-mail antigo, quando o e-mail ou a senha mudam. Se não foi
  # ele, fica sabendo na hora.
  config.send_email_changed_notification = true
  config.send_password_change_notification = true

  # Sessão parada por mais de 2 horas exige novo login (módulo timeoutable).
  config.timeout_in = 2.hours

  # "Sair" só por DELETE (um link GET poderia ser disparado por uma <img> de outro site).
  config.sign_out_via = :delete

  # Códigos HTTP que o Turbo entende: 422 para formulário com erro, 303 para redirecionar
  # depois de um POST/DELETE.
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other
end
