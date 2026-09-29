# Configuração do Stripe (pagamentos em modo de TESTE).
#
# As chaves vêm só de variáveis de ambiente (.env em desenvolvimento), nunca do código:
# - STRIPE_SECRET_KEY: a chave da API. Use uma chave RESTRITA de teste (rk_test_...) com só a
#   permissão "Checkout Sessions: Write".
# - STRIPE_WEBHOOK_SECRET: o segredo que confere a assinatura dos webhooks (whsec_...). Em
#   desenvolvimento, ele aparece quando você roda "stripe listen".
stripe = Rails.configuration.x.stripe

if Rails.env.test?
  # Os testes nunca chamam a API de verdade (WebMock bloqueia a rede); estes valores falsos
  # só precisam ter o formato certo. Assim, o .env da sua máquina não interfere nos testes.
  stripe.secret_key = "sk_test_mercadolite"
  stripe.webhook_secret = "whsec_mercadolitetest"
else
  stripe.secret_key = ENV["STRIPE_SECRET_KEY"].presence
  stripe.webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].presence
end

# Nunca uma chave de produção: a loja é de demonstração e não pode cobrar ninguém de verdade.
# (after_initialize: o StripeKeys, em lib/, só pode ser carregado depois do boot.)
Rails.application.config.after_initialize do
  if stripe.secret_key && !StripeKeys.test_key?(stripe.secret_key)
    raise "STRIPE_SECRET_KEY precisa ser uma chave de TESTE (sk_test_ ou rk_test_). " \
          "O MercadoLite nunca processa pagamentos reais."
  end
  if stripe.webhook_secret && !StripeKeys.webhook_secret?(stripe.webhook_secret)
    raise "STRIPE_WEBHOOK_SECRET deve começar com whsec_."
  end
end

# Tempo máximo de espera pela API. O padrão da gem (30 s para conectar e 80 s para ler)
# prenderia uma thread do servidor por mais de um minuto se o Stripe ficasse lento.
Stripe.open_timeout = 5
Stripe.read_timeout = 20
# Novas tentativas automáticas em falhas de rede. A gem manda a mesma chave de idempotência
# em cada tentativa, então repetir não cria duas cobranças.
Stripe.max_network_retries = 2
