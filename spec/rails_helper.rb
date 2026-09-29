# Configuração do RSpec para testes que precisam do Rails (modelos, requests...).
# Todo arquivo *_spec.rb que testa código Rails começa com: require "rails_helper"
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Trava de segurança: os testes apagam dados, então nunca podem rodar contra produção.
abort("O Rails está em modo produção!") if Rails.env.production?
require "rspec/rails"
# WebMock intercepta todo HTTP de saída: nenhum teste chama a API do Stripe (ou qualquer
# outra) de verdade. Uma chamada não prevista no teste vira erro, e não uma ida à internet.
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)

# Carrega os arquivos de apoio (helpers de teste) em spec/support.
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

# Se houver migration pendente, aplica o schema no banco de teste (ou aborta com o motivo).
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Cada exemplo roda dentro de uma transação que é desfeita (ROLLBACK) no final:
  # o banco volta limpo para o próximo teste, sem precisar apagar nada.
  config.use_transactional_fixtures = true

  # Descobre o tipo do teste pela pasta: spec/models => type: :model, spec/requests => :request.
  config.infer_spec_type_from_file_location!

  # Esconde as linhas internas do Rails nos backtraces de falha.
  config.filter_rails_from_backtrace!

  # Permite escrever create(:product) em vez de FactoryBot.create(:product).
  config.include FactoryBot::Syntax::Methods

  # travel/travel_to: "adiantam o relógio" dentro de um bloco (Time.now fica simulado).
  config.include ActiveSupport::Testing::TimeHelpers

  # O cache guarda os contadores do rate_limit: cada exemplo começa com ele vazio.
  config.before { Rails.cache.clear }
end
