# Gemfile: a lista de dependências (gems) do projeto, lida pelo Bundler.
# Pense no CMakeLists.txt/vcpkg.json de um projeto C++: aqui se declara o que é preciso e
# com qual faixa de versão; o Gemfile.lock (gerado) fixa a versão EXATA de cada gem.
#
# "~> 8.1.4" é o operador pessimista: aceita 8.1.4, 8.1.5... mas não 8.2 (>= 8.1.4, < 8.2).
source "https://rubygems.org"

# O framework. Traz Active Record (ORM), Action Pack (controllers/rotas), Action View
# (templates), Active Storage (uploads), Active Job (tarefas em segundo plano) etc.
gem "rails", "~> 8.1.4"
# Pipeline de assets: serve CSS, JS e imagens com um "digest" no nome (cache eterno seguro).
gem "propshaft"
# Driver do PostgreSQL (extensão nativa em C, ligada à libpq).
gem "pg", "~> 1.1"
# Servidor web (HTTP) multi-thread que roda a aplicação.
gem "puma", ">= 5.0"
# JavaScript via "import maps": o navegador importa módulos ES direto, sem Node nem bundler.
gem "importmap-rails"
# Hotwire: Turbo (navegação rápida sem recarregar a página) e Stimulus (JS pequeno e organizado).
gem "turbo-rails"
gem "stimulus-rails"
# Tailwind CSS (usa o executável standalone do Tailwind; não precisa de Node).
gem "tailwindcss-rails"

# O Windows não traz a base de fusos horários; esta gem a embute (só nessas plataformas).
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Adaptadores "Solid" do Rails 8: cache e fila de jobs guardados no próprio banco,
# sem precisar de Redis. Menos um serviço para manter na VM.
gem "solid_cache"
gem "solid_queue"

# Acelera o boot guardando em cache o resultado de "onde está cada arquivo".
gem "bootsnap", require: false

# Variantes de imagem do Active Storage (miniaturas), usando a libvips.
gem "image_processing", "~> 2.1"
# A partir da image_processing 2.0, a ruby-vips virou dependência OPCIONAL: sem declará-la
# aqui, ela some do bundle e as miniaturas quebram (só em produção, se não houver teste que
# gere uma de verdade). O db/seeds.rb também a usa diretamente (require "vips").
gem "ruby-vips", "~> 2.3"

# Traduções prontas do Rails para pt-BR: mensagens de validação, datas, moeda.
gem "rails-i18n", "~> 8.1"

group :development, :test do
  # Depurador (breakpoints com "debugger" no código).
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Carrega variáveis do arquivo .env (só em desenvolvimento e teste; em produção,
  # as variáveis vêm do ambiente do container).
  gem "dotenv", "~> 3.2"

  # Testes: RSpec (o framework) e FactoryBot (fábricas de objetos para os testes).
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"

  # Segurança: vulnerabilidades conhecidas nas gems (config em config/bundler-audit.yml).
  gem "bundler-audit", require: false

  # Segurança: análise estática do código Rails (SQL injection, XSS, mass assignment...).
  gem "brakeman", require: false

  # Lint e estilo: o conjunto de regras "omakase" do próprio time do Rails.
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Console Ruby na página de erro, só em desenvolvimento.
  gem "web-console"
end
