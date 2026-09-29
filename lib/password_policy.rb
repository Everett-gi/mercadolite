# Regras de senha que vão além do tamanho. Função pura: não toca banco nem Rails.
#
# Segue o NIST SP 800-63B-4: nada de "uma maiúscula, um número e um símbolo" (regras de
# composição só levam a "Senha@123"). O que vale é o comprimento (conferido no modelo User)
# e recusar senhas previsíveis: repetitivas ou derivadas do e-mail ou do nome do serviço.
#
#   PasswordPolicy.weakness("aaaaaaaaaaaaaaaa")                   # => :repetitive
#   PasswordPolicy.weakness("mercadolite-2026!")                  # => :service_name
#   PasswordPolicy.weakness("joana.silva.1234", email: "joana.silva@x.com") # => :email
#   PasswordPolicy.weakness("cavalo correto bateria grampo")      # => nil (passa)
module PasswordPolicy
  # Senha com menos caracteres DIFERENTES que isso é repetitiva ("abababababababab").
  MIN_DISTINCT_CHARS = 5
  # Parte do e-mail antes do @ com pelo menos isso de tamanho não pode aparecer na senha
  # (partes curtas, como "ana", aparecem por acaso dentro de outras palavras).
  MIN_EMAIL_PART = 4
  SERVICE_WORDS = %w[mercadolite].freeze

  # O motivo pelo qual a senha é fraca, ou nil se ela passa.
  #
  # @param password [String]
  # @param email [String, nil] o e-mail da conta, se já conhecido
  # @return [Symbol, nil] :repetitive, :service_name, :email ou nil
  def self.weakness(password, email: nil)
    text = password.to_s.downcase
    local_part = email.to_s.downcase.split("@").first.to_s

    if text.chars.uniq.size < MIN_DISTINCT_CHARS
      :repetitive
    elsif SERVICE_WORDS.any? { |word| text.include?(word) }
      :service_name
    elsif local_part.size >= MIN_EMAIL_PART && text.include?(local_part)
      :email
    end
  end
end
