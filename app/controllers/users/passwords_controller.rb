# "Esqueci minha senha". O Devise faz o trabalho; aqui só limitamos os pedidos, para ninguém
# usar a loja para bombardear a caixa de entrada de outra pessoa.
module Users
  class PasswordsController < Devise::PasswordsController
    include EmailRateLimit

    rate_limit to: 5, within: 15.minutes, only: :create, name: "ip"
    rate_limit to: 3, within: 1.hour, only: :create, name: "email", by: :email_rate_limit_key
  end
end
