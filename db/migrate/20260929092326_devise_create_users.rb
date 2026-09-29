# Compradores da loja. Gerada pelo Devise ("rails g devise User") e enxugada: só as colunas
# dos módulos que usamos (veja app/models/user.rb). Coleta mínima (LGPD): e-mail e hash da
# senha, nada de nome, CPF ou IP.
class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## database_authenticatable
      # O Devise já grava o e-mail em minúsculas e sem espaços; os CHECKs abaixo garantem o
      # mesmo no banco (254 caracteres é o limite prático de um endereço de e-mail).
      t.string :email, null: false
      # Hash bcrypt (60 caracteres), nunca a senha. O nome "encrypted" é histórico: hash não
      # é criptografia, não dá para "decifrar".
      t.string :encrypted_password, null: false

      ## recoverable — o banco guarda um HMAC do token de redefinição, não o token enviado
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## confirmable — a conta só entra depois de confirmar o e-mail
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # e-mail novo, esperando confirmação

      # LGPD: quando a pessoa aceitou os Termos de Uso e a Política de Privacidade.
      t.datetime :terms_accepted_at, null: false

      # Muda a cada "Sair": invalida todas as cópias do cookie de sessão deste usuário
      # (veja User#authenticatable_salt).
      t.string :session_token, null: false

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :session_token,        unique: true

    add_check_constraint :users, "email = lower(btrim(email))", name: "users_email_normalized"
    add_check_constraint :users, "char_length(email) BETWEEN 3 AND 254", name: "users_email_length"
  end
end
