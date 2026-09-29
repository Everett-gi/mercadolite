# Comprador da loja. A autenticação vem do Devise; cada símbolo em "devise" liga um módulo
# (um mixin) que acrescenta colunas, validações, rotas e telas:
#
# - database_authenticatable: e-mail + senha, guardada como hash bcrypt.
# - registerable: cadastro, edição e exclusão da própria conta (LGPD).
# - recoverable: "esqueci minha senha", com token de uso único que expira.
# - validatable: formato do e-mail, e-mail único, tamanho e confirmação da senha.
# - confirmable: a conta só entra depois de confirmar o e-mail (ninguém cadastra o
#   e-mail de outra pessoa).
# - timeoutable: sessão parada por mais que Devise.timeout_in exige novo login.
#
# Ficaram de fora: trackable (guardaria IPs: dado pessoal que não usamos), rememberable
# (a sessão já dura o bastante) e lockable (o rate limit por e-mail cumpre esse papel sem
# deixar um atacante travar a conta dos outros).
class User < ApplicationRecord
  # bcrypt só considera os primeiros 72 BYTES da senha e ignora o resto em silêncio.
  MAX_PASSWORD_BYTES = 72
  # Conta nunca confirmada é apagada depois disso (o link de confirmação vale 3 dias). Assim,
  # quem cadastrou o e-mail de outra pessoa não "ocupa" esse e-mail para sempre.
  UNCONFIRMED_EXPIRES_AFTER = 7.days

  devise :database_authenticatable, :registerable, :recoverable, :validatable,
         :confirmable, :timeoutable

  # Gera um session_token aleatório (SecureRandom) na criação.
  has_secure_token :session_token
  has_one :cart, dependent: :destroy

  # Caixa "Li e aceito os termos" do cadastro. É um atributo virtual (não é coluna).
  # allow_nil: false — sem isso, a validação é PULADA quando o campo nem é enviado.
  validates :terms_of_service, acceptance: { allow_nil: false }, on: :create
  validates :email, length: { maximum: 254 }
  validate :password_fits_bcrypt, :password_not_predictable, if: -> { password.present? }

  before_create { self.terms_accepted_at = Time.current }

  scope :expired_unconfirmed, -> { where(confirmed_at: nil, created_at: ...UNCONFIRMED_EXPIRES_AFTER.ago) }

  # O "sal" que o Devise grava no cookie de sessão junto com o id. A cada requisição ele é
  # comparado com o do banco: se mudou, a sessão deixa de valer. O padrão do Devise é o
  # sal do bcrypt (muda quando a senha muda); acrescentamos o session_token, que muda a cada
  # "Sair" (end_all_sessions!). Assim, uma cópia antiga do cookie não volta a entrar.
  #
  # @return [String, nil]
  def authenticatable_salt
    "#{super}#{session_token}"
  end

  # Invalida TODAS as sessões desta conta, em todos os aparelhos. Chamado ao sair e quando a
  # sessão expira por inatividade (veja config/initializers/warden_hooks.rb).
  #
  # @return [void]
  def end_all_sessions!
    # update_column: grava só esta coluna, sem validações nem callbacks.
    update_column(:session_token, self.class.generate_unique_secure_token)
  end

  private

  # Envia os e-mails do Devise (confirmação, redefinição de senha...) por um job, fora da
  # requisição. Dois motivos: a resposta não espera o servidor SMTP, e o tempo de resposta
  # não revela se o e-mail existe na base (o modo paranoid do Devise responde a mesma
  # mensagem nos dois casos, e o tempo também precisa ser parecido).
  #
  # after_all_transactions_commit: se há uma transação aberta (o Devise chama isto dentro
  # de callbacks do save), o job só entra na fila depois do COMMIT. Senão ele poderia rodar
  # antes e ler o registro antigo (um e-mail novo que ainda não foi gravado, por exemplo).
  # Sem transação aberta, o bloco roda na hora.
  def send_devise_notification(notification, *args)
    message = devise_mailer.send(notification, self, *args)
    ActiveRecord.after_all_transactions_commit { message.deliver_later }
  end

  # Senhas com acento ocupam 2 bytes por letra: "é" * 40 tem 40 caracteres e 80 bytes.
  # Só acrescenta o erro quando a contagem de caracteres (do Devise) não pegou.
  def password_fits_bcrypt
    return if password.bytesize <= MAX_PASSWORD_BYTES || password.length > MAX_PASSWORD_BYTES

    errors.add(:password, :too_many_bytes, count: MAX_PASSWORD_BYTES)
  end

  def password_not_predictable
    reason = PasswordPolicy.weakness(password, email:)
    errors.add(:password, :"predictable_#{reason}") if reason
  end
end
