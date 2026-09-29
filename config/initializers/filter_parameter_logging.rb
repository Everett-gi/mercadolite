# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # O conteúdo dos eventos de webhook do Stripe (a chave "data" do JSON). Ele traz nome,
  # e-mail e endereço do comprador, e o Rails escreve no log os parâmetros de toda requisição,
  # inclusive em produção. A expressão casa só com a chave "data" exata (e não com "metadata").
  /\Adata\z/
]
