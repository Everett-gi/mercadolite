require "rails_helper"

# Os cabeçalhos de segurança são uma promessa do projeto (SECURITY.md). Este teste
# garante que nenhuma mudança de configuração os remova em silêncio.
RSpec.describe "Cabeçalhos de segurança", type: :request do
  before { get rails_health_check_path }

  let(:csp) { response.headers["Content-Security-Policy"] }

  it "envia uma CSP restrita ao próprio site" do
    expect(csp).to include("default-src 'self'")
    expect(csp).to include("object-src 'none'")
    expect(csp).to include("frame-ancestors 'none'")
    expect(csp).to include("base-uri 'self'")
    expect(csp).to include("form-action 'self'")
  end

  it "não libera scripts inline nem eval na CSP" do
    expect(csp).not_to include("unsafe-inline")
    expect(csp).not_to include("unsafe-eval")
  end

  it "gera um nonce diferente a cada requisição" do
    first_nonce = csp[/'nonce-([^']+)'/, 1]
    get rails_health_check_path
    second_nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]

    expect(first_nonce).to be_present
    expect(second_nonce).not_to eq(first_nonce)
  end

  it "impede o navegador de adivinhar o tipo do conteúdo" do
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
  end

  it "proíbe exibir o site dentro de um iframe (clickjacking)" do
    expect(response.headers["X-Frame-Options"]).to eq("DENY")
  end

  it "desliga câmera, microfone e geolocalização" do
    policy = response.headers["Permissions-Policy"]
    expect(policy).to include("camera=()", "microphone=()", "geolocation=()")
  end
end
