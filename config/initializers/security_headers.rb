# Cabeçalhos de segurança enviados em TODA resposta, além dos que o Rails já manda por
# padrão (X-Content-Type-Options: nosniff, Referrer-Policy etc.). A CSP fica no
# content_security_policy.rb, e o HSTS é ligado pelo config.force_ssl em produção.

# Permissions-Policy: desliga recursos do navegador que a loja não usa. Se um script
# malicioso rodar na página, ele não consegue ligar câmera, microfone, GPS etc.
#
# Por que não o "config.permissions_policy" do Rails? Na versão 8.1 ele ainda emite o
# cabeçalho antigo "Feature-Policy", que os navegadores atuais ignoram. O pagamento
# acontece na página do Stripe (Checkout hospedado), por isso "payment" também é negado.
Rails.application.config.action_dispatch.default_headers.merge!(
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), usb=(), " \
                          "gyroscope=(), payment=(), fullscreen=(self)",
  # Nenhuma página nossa deve ser exibida dentro de um <iframe> (clickjacking). A CSP
  # frame-ancestors já cobre navegadores modernos; este cobre os antigos.
  "X-Frame-Options" => "DENY"
)
