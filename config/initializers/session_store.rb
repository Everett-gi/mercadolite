# Sessão do navegador guardada num COOKIE, cifrado (AES-256-GCM) e assinado com a
# SECRET_KEY_BASE: o navegador guarda o conteúdo, mas não consegue lê-lo nem alterá-lo.
# Nela ficam só o id do carrinho e o token anti-CSRF — nada de dado pessoal.
Rails.application.config.session_store :cookie_store,
  key: "_mercadolite_session",
  # O cookie sobrevive ao fechamento do navegador por 30 dias (renovados a cada visita),
  # o mesmo prazo em que o PurgeAbandonedCartsJob apaga carrinhos parados.
  expire_after: 30.days,
  # Lax: o navegador não envia o cookie em POSTs vindos de outros sites (defesa extra
  # contra CSRF), mas envia ao seguir um link para a loja.
  same_site: :lax,
  # Em produção, o cookie só trafega por HTTPS. (O HttpOnly, que esconde o cookie do
  # JavaScript da página, já vem ligado por padrão.)
  secure: Rails.env.production?
