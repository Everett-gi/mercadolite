require "rails_helper"
require "bcrypt" # o Devise só carrega o bcrypt no primeiro hash; o teste abaixo o usa direto

RSpec.describe User do
  describe "e-mail" do
    it "é gravado em minúsculas e sem espaços" do
      user = create(:user, email: "  Joana.Silva@Exemplo.COM ")

      expect(user.email).to eq("joana.silva@exemplo.com")
    end

    it "é único, sem diferenciar maiúsculas" do
      create(:user, email: "joana@exemplo.com")
      duplicate = build(:user, email: "JOANA@exemplo.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to be_present
    end

    it "tem no máximo 254 caracteres" do
      user = build(:user, email: "#{"a" * 243}@exemplo.com") # 255

      expect(user).not_to be_valid
    end
  end

  describe "senha" do
    it "é guardada só como hash bcrypt" do
      user = create(:user, password: "trem azul noturno 42")

      expect(user.encrypted_password).to start_with("$2a$")
      expect(user.encrypted_password).not_to include("trem azul")
      expect(user.valid_password?("trem azul noturno 42")).to be(true)
    end

    it "tem no mínimo 15 caracteres" do
      expect(build(:user, password: "a1b2c3d4e5f6g7")).not_to be_valid # 14
      expect(build(:user, password: "a1b2c3d4e5f6g7h")).to be_valid     # 15
    end

    # O motivo do limite: o bcrypt IGNORA o que passa de 72 bytes. Duas senhas que só
    # diferem depois disso dariam o mesmo hash.
    it "o bcrypt ignora o que passa de 72 bytes (por isso o limite)" do
      hash = BCrypt::Password.create("#{"a1b2c3d4" * 9}X", cost: 4) # 73 bytes

      expect(hash == "#{"a1b2c3d4" * 9}Y").to be(true)
    end

    it "tem no máximo 72 caracteres" do
      expect(build(:user, password: "abcdefgh" * 9)).to be_valid          # 72
      expect(build(:user, password: "#{"abcdefgh" * 9}i")).not_to be_valid # 73
    end

    it "tem no máximo 72 BYTES: letras com acento contam 2" do
      user = build(:user, password: "ção é ávido #{"ç" * 30}") # 42 caracteres, 76 bytes

      expect(user.password.length).to be <= 72
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("é longa demais: use até 72 bytes (letras com acento contam 2)")
    end

    it "recusa senha previsível (repetitiva, com o nome da loja ou com o e-mail)" do
      expect(build(:user, password: "abababababababab")).not_to be_valid
      expect(build(:user, password: "mercadolite-2026-ok")).not_to be_valid
      expect(build(:user, email: "joana.silva@exemplo.com", password: "joana.silva-1234")).not_to be_valid
    end
  end

  describe "aceite dos termos (LGPD)" do
    it "é obrigatório no cadastro, mesmo quando o campo nem é enviado" do
      expect(build(:user, terms_of_service: nil)).not_to be_valid
      expect(build(:user, terms_of_service: "0")).not_to be_valid
    end

    it "grava quando os termos foram aceitos" do
      freeze_time do
        expect(create(:user).terms_accepted_at).to eq(Time.current)
      end
    end

    it "não é exigido de novo ao editar a conta" do
      user = create(:user)

      expect(User.find(user.id).update(email: "novo@exemplo.test")).to be(true)
    end
  end

  describe "sessões" do
    it "cada conta nasce com um session_token aleatório" do
      a = create(:user)
      b = create(:user)

      expect(a.session_token).to be_present
      expect(a.session_token).not_to eq(b.session_token)
    end

    # O "sal" vai para o cookie de sessão; mudar o sal invalida as cópias do cookie.
    it "end_all_sessions! troca o sal da sessão" do
      user = create(:user)
      before = user.authenticatable_salt

      user.end_all_sessions!

      expect(user.reload.authenticatable_salt).not_to eq(before)
    end

    it "trocar a senha também troca o sal" do
      user = create(:user)
      before = user.authenticatable_salt

      user.update!(password: "outra frase bem longa 7", password_confirmation: "outra frase bem longa 7")

      expect(user.authenticatable_salt).not_to eq(before)
    end
  end

  describe "e-mails" do
    include ActiveJob::TestHelper

    it "envia a confirmação por job, depois do commit" do
      expect { create(:user, :unconfirmed) }
        .to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
    end

    it "não escreve no log o token do link (argumento do job)" do
      user = create(:user)
      log = StringIO.new
      original = ActiveJob::Base.logger
      ActiveJob::Base.logger = ActiveSupport::Logger.new(log)

      token = user.send_reset_password_instructions

      expect(log.string).to include("Enqueued ActionMailer::MailDeliveryJob")
      expect(log.string).not_to include(token)
    ensure
      ActiveJob::Base.logger = original
    end

    it "o link do e-mail leva o token, e o banco guarda só um HMAC dele" do
      user = create(:user)
      token = nil

      perform_enqueued_jobs { token = user.send_reset_password_instructions }

      expect(ActionMailer::Base.deliveries.last.body.encoded).to include("reset_password_token=#{token}")
      expect(user.reload.reset_password_token).not_to eq(token)
    end
  end

  describe "restrições no banco" do
    let(:user) { create(:user) }

    it "recusa e-mail fora do padrão gravado direto no SQL" do
      expect { user.update_column(:email, "Joana@Exemplo.com") }
        .to raise_error(ActiveRecord::StatementInvalid, /users_email_normalized/)
    end

    it "recusa e-mail repetido (índice único)" do
      expect { create(:user).update_column(:email, user.email) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "exige a data do aceite dos termos" do
      expect { user.update_column(:terms_accepted_at, nil) }
        .to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "exclusão" do
    it "apaga o carrinho da conta e os itens dele" do
      user = create(:user)
      cart = create(:cart, user:)
      cart.add(create(:product, stock: 5), 1)

      user.destroy!

      expect(Cart.exists?(cart.id)).to be(false)
      expect(CartItem.where(cart_id: cart.id)).to be_empty
    end
  end

  describe ".expired_unconfirmed" do
    it "pega só contas não confirmadas criadas há mais de 7 dias" do
      old = create(:user, :unconfirmed, created_at: 8.days.ago)
      create(:user, :unconfirmed, created_at: 6.days.ago)
      create(:user, created_at: 30.days.ago) # confirmada

      expect(User.expired_unconfirmed).to contain_exactly(old)
    end
  end
end
