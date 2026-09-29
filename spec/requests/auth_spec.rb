require "rails_helper"
require "bcrypt"

RSpec.describe "Contas (login do comprador)", type: :request do
  include ActiveJob::TestHelper

  SESSION_COOKIE = "_mercadolite_session".freeze

  let(:user) { create(:user) }
  let(:product) { create(:product, name: "Caneca azul", stock: 5) }

  # Login pelo formulário, como o navegador faria (passa por toda a pilha: rate limit,
  # Warden, ganchos do carrinho).
  def log_in(email:, password:, ip: "127.0.0.1")
    post user_session_path, params: { user: { email:, password: } }, env: { "REMOTE_ADDR" => ip }
  end

  def add_to_cart(product, quantity: 1)
    post cart_items_path, params: { cart_item: { product_id: product.id, quantity: } }
  end

  def signed_in?
    get edit_user_registration_path
    response.ok?
  end

  describe "cadastro" do
    let(:form) do
      { email: "joana@exemplo.test", password: "trem azul noturno 42",
        password_confirmation: "trem azul noturno 42", terms_of_service: "1" }
    end

    it "cria a conta sem confirmar, envia o e-mail de confirmação e não faz login" do
      expect { post user_registration_path, params: { user: form } }
        .to change(User, :count).by(1)
        .and have_enqueued_mail(Devise::Mailer, :confirmation_instructions)

      expect(User.sole).not_to be_confirmed
      expect(signed_in?).to be(false)
    end

    it "exige o aceite dos termos" do
      expect { post user_registration_path, params: { user: form.except(:terms_of_service) } }
        .not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Os Termos de Uso e a Política de Privacidade precisam ser aceitos")
    end

    it "linka os Termos de Uso e a Política de Privacidade" do
      get new_user_registration_path

      expect(response.body).to include(terms_path, privacy_path)
    end
  end

  describe "login" do
    it "entra com e-mail em qualquer caixa e senha certa" do
      log_in(email: user.email.upcase, password: user.password)

      expect(response).to redirect_to(root_path)
      expect(signed_in?).to be(true)
    end

    # Enumeração: a resposta não pode revelar se o e-mail tem conta.
    it "dá a mesma mensagem para senha errada e para e-mail inexistente" do
      log_in(email: user.email, password: "senha errada mas comprida")
      wrong_password = [ response.status, flash[:alert] ]

      log_in(email: "ninguem@exemplo.test", password: "senha errada mas comprida")
      unknown_email = [ response.status, flash[:alert] ]

      expect(wrong_password).to eq(unknown_email)
      expect(unknown_email.last).to eq("E-mail ou senha inválidos.")
    end

    # Cada hash bcrypt custa ~250 ms. Se o login com e-mail inexistente calculasse MENOS
    # hashes, responderia mais rápido, e o TEMPO revelaria quem tem conta.
    it "calcula a mesma quantidade de hashes bcrypt exista ou não o e-mail" do
      email = user.email # cria a conta ANTES de começar a contar (criar também calcula hash)
      hashes = 0
      allow(BCrypt::Engine).to receive(:hash_secret).and_wrap_original do |original, *args|
        hashes += 1
        original.call(*args)
      end

      log_in(email:, password: "senha errada mas comprida")
      wrong_password = hashes
      log_in(email: "ninguem@exemplo.test", password: "senha errada mas comprida")
      unknown_email = hashes - wrong_password

      expect(wrong_password).to be_positive
      expect(unknown_email).to eq(wrong_password)
    end

    it "não deixa entrar quem ainda não confirmou o e-mail" do
      pending_user = create(:user, :unconfirmed)

      log_in(email: pending_user.email, password: pending_user.password)

      expect(flash[:alert]).to eq("Antes de continuar, confirme a sua conta.")
      expect(signed_in?).to be(false)
    end

    it "o link do e-mail confirma a conta" do
      pending_user = create(:user, :unconfirmed)
      token = pending_user.confirmation_token # o Devise guarda este token como está

      get user_confirmation_path(confirmation_token: token)

      expect(pending_user.reload).to be_confirmed
    end
  end

  describe "proteção CSRF no login" do
    include_context "com proteção CSRF ligada"

    # Sem o token, um site atacante poderia logar a vítima na conta DELE (login CSRF) e ver
    # tudo o que ela fizer depois.
    it "recusa o login sem o token do formulário" do
      log_in(email: user.email, password: user.password)

      expect(response).to have_http_status(:unprocessable_content)
      expect(signed_in?).to be(false)
    end

    # O Devise troca o token CSRF da sessão no login: um token conhecido antes (plantado por
    # um atacante, por exemplo) não serve depois. Cada formulário tem o próprio token, preso à
    # ação dele, por isso o teste pega o do formulário do carrinho.
    it "o token CSRF de um formulário aberto antes do login deixa de valer" do
      cart_token = -> { response.body[%r{action="/cart_items".*?name="authenticity_token" value="([^"]+)"}m, 1] }
      get product_path(product)
      token_before = cart_token.call
      get new_user_session_path
      login_token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
      post user_session_path, params: { authenticity_token: login_token, user: { email: user.email, password: user.password } }

      post cart_items_path, params: { authenticity_token: token_before, cart_item: { product_id: product.id, quantity: 1 } }
      expect(response).to have_http_status(:unprocessable_content)

      get product_path(product)
      post cart_items_path, params: { authenticity_token: cart_token.call, cart_item: { product_id: product.id, quantity: 1 } }
      expect(response).to redirect_to(cart_path)
    end
  end

  describe "sessão" do
    it "sair invalida TODAS as cópias do cookie de sessão" do
      log_in(email: user.email, password: user.password)
      stolen = cookies[SESSION_COOKIE] # por exemplo, copiado por um malware

      delete destroy_user_session_path
      expect(signed_in?).to be(false)

      cookies[SESSION_COOKIE] = stolen
      expect(signed_in?).to be(false)
    end

    it "trocar a senha derruba as sessões abertas em outros lugares" do
      log_in(email: user.email, password: user.password)
      other_device = cookies[SESSION_COOKIE]

      patch user_registration_path, params: { user: {
        password: "outra frase bem longa 7", password_confirmation: "outra frase bem longa 7",
        current_password: user.password
      } }
      expect(signed_in?).to be(true) # quem trocou continua dentro

      cookies[SESSION_COOKIE] = other_device
      expect(signed_in?).to be(false)
    end

    it "expira depois de 2 horas sem uso, e a expiração também invalida as cópias do cookie" do
      log_in(email: user.email, password: user.password)
      token = user.reload.session_token

      travel(2.hours + 1.minute) do
        get edit_user_registration_path
        # O Devise volta para a página pedida com o aviso; ela, sem login, manda para o login.
        expect(flash[:alert]).to eq("A sua sessão expirou, por favor, faça login novamente para continuar.")
        follow_redirect!
        expect(response).to redirect_to(new_user_session_path)
      end

      expect(user.reload.session_token).not_to eq(token)
    end

    it "o cookie é HttpOnly e SameSite=Lax" do
      log_in(email: user.email, password: user.password)

      cookie = Array(response.headers["Set-Cookie"]).join("\n")
      expect(cookie).to match(/#{SESSION_COOKIE}=/)
      expect(cookie).to match(/httponly/i)
      expect(cookie).to match(/samesite=lax/i)
    end
  end

  describe "carrinho e login" do
    it "o carrinho de visitante passa a ser da conta no login" do
      add_to_cart(product, quantity: 2)

      log_in(email: user.email, password: user.password)

      expect(user.reload.cart.items.sole.quantity).to eq(2)
      expect(Cart.guest).to be_empty
    end

    it "soma ao carrinho que a conta já tinha" do
      create(:cart, user:).add(product, 2)
      add_to_cart(product, quantity: 1)

      log_in(email: user.email, password: user.password)

      expect(Cart.sole.user).to eq(user)
      expect(Cart.sole.items.sole.quantity).to eq(3)
    end

    it "uma cópia do cookie de VISITANTE não alcança o carrinho depois do login" do
      add_to_cart(product)
      guest_cookie = cookies[SESSION_COOKIE]
      log_in(email: user.email, password: user.password)

      cookies[SESSION_COOKIE] = guest_cookie
      get cart_path

      expect(response.body).to include("Seu carrinho está vazio")
      # Nem fica logado (session fixation): o login foi gravado no cookie NOVO.
      expect(signed_in?).to be(false)
    end

    it "sair tira o carrinho do navegador, e entrar de novo o traz de volta" do
      log_in(email: user.email, password: user.password)
      add_to_cart(product, quantity: 2)

      delete destroy_user_session_path
      get cart_path
      expect(response.body).to include("Seu carrinho está vazio")

      log_in(email: user.email, password: user.password)
      get cart_path
      expect(response.body).to include("Caneca azul")
    end

    it "conta não confirmada não leva o carrinho de visitante" do
      pending_user = create(:user, :unconfirmed)
      add_to_cart(product)

      log_in(email: pending_user.email, password: pending_user.password)

      expect(Cart.sole.user).to be_nil
      get cart_path
      expect(response.body).to include("Caneca azul")
    end

    it "anti-IDOR: uma conta não mexe no item do carrinho de outra" do
      other_item = create(:cart, user: create(:user)).add(product, 1)
      log_in(email: user.email, password: user.password)

      patch cart_item_path(other_item), params: { cart_item: { quantity: "3" } }
      expect(response).to have_http_status(:not_found)
      delete cart_item_path(other_item)
      expect(response).to have_http_status(:not_found)

      expect(other_item.reload.quantity).to eq(1)
    end
  end

  describe "esqueci minha senha" do
    it "dá a mesma resposta exista ou não a conta, e só manda e-mail se existir" do
      expect { post user_password_path, params: { user: { email: "ninguem@exemplo.test" } } }
        .not_to have_enqueued_mail
      unknown = [ response.status, response.location, flash[:notice] ]

      expect { post user_password_path, params: { user: { email: user.email } } }
        .to have_enqueued_mail(Devise::Mailer, :reset_password_instructions)
      known = [ response.status, response.location, flash[:notice] ]

      expect(known).to eq(unknown)
    end

    it "o link vale por 1 hora" do
      token = user.send_reset_password_instructions
      form = { reset_password_token: token, password: "outra frase bem longa 7",
               password_confirmation: "outra frase bem longa 7" }

      travel(1.hour + 1.minute) do
        put user_password_path, params: { user: form }
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("outra frase bem longa 7")).to be(false)
    end
  end

  describe "rate limit" do
    it "por IP: a 11ª tentativa de login em 3 minutos recebe 429" do
      10.times { |i| log_in(email: "tentativa#{i}@exemplo.test", password: "senha errada mas comprida") }
      expect(response).to have_http_status(:unprocessable_content)

      log_in(email: user.email, password: user.password)

      expect(response).to have_http_status(:too_many_requests)
    end

    # Ataque distribuído: cada tentativa vem de um IP diferente, mas todas contra a mesma conta.
    it "por e-mail: a 6ª tentativa na mesma conta recebe 429, venha de onde vier" do
      5.times { |i| log_in(email: user.email, password: "senha errada mas comprida", ip: "10.0.0.#{i}") }

      log_in(email: user.email.upcase, password: user.password, ip: "10.0.1.1")

      expect(response).to have_http_status(:too_many_requests)
    end

    it "libera de novo depois da janela de 15 minutos" do
      5.times { |i| log_in(email: user.email, password: "senha errada mas comprida", ip: "10.0.0.#{i}") }

      travel(15.minutes + 1.second) do
        log_in(email: user.email, password: user.password, ip: "10.0.1.1")
      end

      expect(response).to redirect_to(root_path)
    end

    it "no máximo 3 e-mails de redefinição por hora para o mesmo endereço" do
      expect {
        4.times { |i| post user_password_path, params: { user: { email: user.email } }, env: { "REMOTE_ADDR" => "10.0.0.#{i}" } }
      }.to have_enqueued_mail(Devise::Mailer, :reset_password_instructions).exactly(3).times

      expect(response).to have_http_status(:too_many_requests)
    end

    it "no máximo 5 cadastros a cada 15 minutos por IP" do
      6.times { |i| post user_registration_path, params: { user: { email: "robo#{i}@exemplo.test" } } }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "excluir a conta (LGPD)" do
    before do
      log_in(email: user.email, password: user.password)
      add_to_cart(product)
    end

    it "exige a senha atual" do
      delete user_registration_path, params: { user: { current_password: "senha errada mas comprida" } }

      expect(response).to redirect_to(edit_user_registration_path)
      expect(flash[:alert]).to eq("Senha incorreta. A conta não foi excluída.")
      expect(User.exists?(user.id)).to be(true)
    end

    it "responde 400 sem o campo da senha" do
      delete user_registration_path

      expect(response).to have_http_status(:bad_request)
      expect(User.exists?(user.id)).to be(true)
    end

    it "com a senha certa, apaga a conta e o carrinho e encerra a sessão" do
      delete user_registration_path, params: { user: { current_password: user.password } }

      expect(User.exists?(user.id)).to be(false)
      expect(Cart.count).to eq(0)
      expect(signed_in?).to be(false)
    end
  end

  describe "páginas da LGPD" do
    it "mostra os Termos de Uso e a Política de Privacidade" do
      get terms_path
      expect(response.body).to include("Termos de Uso")

      get privacy_path
      expect(response.body).to include("Política de Privacidade", "estritamente necessário")
    end
  end
end
