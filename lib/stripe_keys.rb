# Regras sobre as chaves do Stripe. Função pura: não toca rede nem Rails.
#
# O MercadoLite é uma loja de demonstração: ela NUNCA pode processar um pagamento real. Por
# isso só aceita chaves de TESTE (sandbox), e de preferência a chave restrita (rk_), que só
# tem as permissões necessárias.
#
#   StripeKeys.test_key?("rk_test_51ABC...")    # => true
#   StripeKeys.test_key?("rkcs_test_51ABC...")  # => true (restrita, de sandbox criada pela CLI)
#   StripeKeys.test_key?("sk_live_51ABC...")    # => false (chave de produção!)
#   StripeKeys.test_key?("pk_test_51ABC...")    # => false (a publicável não serve no servidor)
#   StripeKeys.webhook_secret?("whsec_abc")     # => true
module StripeKeys
  # sk... = chave secreta (acesso total), rk... = chave restrita (acesso escolhido). O Stripe
  # tem variações do prefixo (a sandbox criada pela CLI entrega "rkcs_test_..."), então vale
  # qualquer sk/rk seguido de letras, desde que seja de TESTE.
  TEST_KEY = /\A(sk|rk)[a-z]*_test_[0-9A-Za-z]+\z/
  WEBHOOK_SECRET = /\Awhsec_[0-9A-Za-z]+\z/

  # @param key [String, nil]
  # @return [Boolean] se é uma chave secreta ou restrita de TESTE
  def self.test_key?(key)
    TEST_KEY.match?(key.to_s)
  end

  # @param secret [String, nil]
  # @return [Boolean] se tem o formato do segredo de assinatura dos webhooks
  def self.webhook_secret?(secret)
    WEBHOOK_SECRET.match?(secret.to_s)
  end
end
