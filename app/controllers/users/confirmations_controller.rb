# "Reenviar e-mail de confirmação". Mesmos limites do "esqueci minha senha".
module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include EmailRateLimit

    rate_limit to: 5, within: 15.minutes, only: :create, name: "ip"
    rate_limit to: 3, within: 1.hour, only: :create, name: "email", by: :email_rate_limit_key
  end
end
