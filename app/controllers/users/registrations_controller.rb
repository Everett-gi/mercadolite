# Cadastro, edição e exclusão da própria conta (Devise::RegistrationsController), com:
# - aceite dos termos no cadastro (LGPD);
# - limites de tentativas;
# - senha exigida para EXCLUIR a conta (o Devise, por padrão, não pede).
module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :permit_terms_of_service, only: :create

    rate_limit to: 5, within: 15.minutes, only: :create, name: "ip"
    # Editar e excluir exigem a senha atual: sem limite, dariam para adivinhá-la estando com
    # a sessão de outra pessoa aberta. O limite é por conta (o login já passou).
    rate_limit to: 5, within: 15.minutes, only: %i[update destroy], name: "account", by: -> { current_user.id }

    # DELETE /users   user[current_password]
    def destroy
      password = params.expect(user: [ :current_password ])[:current_password]
      return super if resource.valid_password?(password)

      redirect_to edit_user_registration_path, alert: t(".wrong_password"), status: :see_other
    end

    private

    # O Devise só aceita e-mail e senha no cadastro (strong parameters); o aceite dos termos
    # precisa ser liberado aqui.
    def permit_terms_of_service
      devise_parameter_sanitizer.permit(:sign_up, keys: [ :terms_of_service ])
    end
  end
end
