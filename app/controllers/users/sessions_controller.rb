# Login e logout. Toda a lógica é do Devise (Devise::SessionsController); aqui só entram os
# limites de tentativas, contra adivinhação de senha:
# - por IP: segura um robô testando muitas contas a partir de uma máquina;
# - por e-mail: segura muitas máquinas atacando a MESMA conta.
# Acima do limite, 429 (public/429.html) antes mesmo de conferir a senha.
module Users
  class SessionsController < Devise::SessionsController
    include EmailRateLimit

    rate_limit to: 10, within: 3.minutes, only: :create, name: "ip"
    rate_limit to: 5, within: 15.minutes, only: :create, name: "email", by: :email_rate_limit_key
  end
end
