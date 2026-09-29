# Content Security Policy (CSP): um cabeçalho HTTP que diz ao navegador de ONDE a página
# pode carregar scripts, estilos, imagens etc. É a principal defesa em profundidade
# contra XSS: mesmo que um atacante consiga injetar um <script> no HTML, o navegador se
# recusa a executá-lo, porque ele não veio de uma origem permitida nem tem o nonce certo.
#
# Guia: https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self            # padrão para tudo o que não for listado: só o próprio site
    policy.script_src  :self            # JS só do próprio site (+ nonce, abaixo)
    policy.style_src   :self            # CSS só do próprio site (+ nonce, abaixo)
    policy.img_src     :self            # imagens (inclusive as do Active Storage) do próprio site
    policy.font_src    :self
    policy.connect_src :self            # fetch/XHR (o Turbo usa) só para o próprio site
    policy.object_src  :none            # nada de <object>/<embed> (plugins)
    policy.base_uri    :self            # impede um <base href> injetado de desviar URLs relativas
    policy.form_action :self            # formulários só enviam para o próprio site
    policy.frame_ancestors :none        # ninguém pode colocar o site num <iframe> (clickjacking)
  end

  # Nonce ("number used once"): um valor aleatório novo a cada requisição, colocado no
  # cabeçalho CSP e nas tags <script>/<style> legítimas geradas pelo Rails (importmap) e
  # lido pelo Turbo (meta csp-nonce). Um script injetado não sabe o valor e é bloqueado.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
