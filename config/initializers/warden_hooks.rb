# Ganchos (callbacks) do Warden, o middleware Rack sobre o qual o Devise é construído. Eles
# rodam em QUALQUER login ou logout, venha de onde vier: tela de login, redefinição de senha,
# expiração da sessão. Por isso ficam aqui, e não nos controllers.

# Depois do login. "except: :fetch" pula o caso em que o usuário só está sendo lido da sessão
# (isso acontece em toda requisição); sobra o login de fato.
Warden::Manager.after_set_user except: :fetch, scope: :user do |user, warden, _options|
  # Conta ainda não confirmada: o Devise vai recusar o login logo em seguida.
  next unless user.active_for_authentication?

  # O carrinho de visitante passa a ser do usuário (ou é somado ao que ele já tinha). Depois
  # disso, o id do carrinho sai da sessão: quem ainda tiver uma cópia do cookie antigo de
  # visitante não alcança mais esse carrinho.
  session = warden.request.session
  Cart.claim(Cart.guest.find_by(id: session.delete(:cart_id)), user)
end

# Antes do logout (inclusive o automático, por inatividade). Troca o session_token da conta,
# o que invalida todas as cópias do cookie de sessão (veja User#authenticatable_salt).
Warden::Manager.before_logout scope: :user do |user, _warden, _options|
  # user é nil se ninguém estava logado; e uma conta recém-excluída não se grava mais.
  user.end_all_sessions! if user&.persisted?
end
