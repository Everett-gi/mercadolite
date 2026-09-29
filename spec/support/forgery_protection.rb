# No ambiente de teste a proteção CSRF vem desligada (config/environments/test.rb), para os
# testes não precisarem buscar o token em cada formulário. Este contexto a liga de propósito,
# para provar que ela funciona:
#
#   include_context "com proteção CSRF ligada"
RSpec.shared_context "com proteção CSRF ligada" do
  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
