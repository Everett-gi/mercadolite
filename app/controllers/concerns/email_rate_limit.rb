# Chave para limitar tentativas POR E-MAIL (além do limite por IP), usada nos controllers de
# login, "esqueci a senha" e "reenviar confirmação". O limite por IP sozinho não segura um
# ataque distribuído contra UMA conta; o limite por e-mail segura.
module EmailRateLimit
  extend ActiveSupport::Concern

  private

  # O e-mail do formulário, normalizado como o Devise faz, passado por SHA-256: o contador
  # fica no cache (Solid Cache, no banco) e não precisa guardar o e-mail em si (LGPD).
  #
  # @return [String] hash hexadecimal (o de "" quando o formulário não traz e-mail)
  def email_rate_limit_key
    fields = params[:user]
    email = fields.is_a?(ActionController::Parameters) ? fields[:email].to_s.strip.downcase : ""
    Digest::SHA256.hexdigest(email)
  end
end
