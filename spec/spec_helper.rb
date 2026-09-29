# Configuração do RSpec que NÃO depende do Rails (carregada pelo .rspec em todo teste).
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    # Mensagens de falha de matchers compostos (ex.: "a and b") mostram a descrição completa.
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # Falha se um "double" simular um método que o objeto real não tem.
    mocks.verify_partial_doubles = true
  end

  # Grupos compartilhados (shared_context) passam a valer para todos os metadados.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Permite rodar só os exemplos marcados com "focus: true" (ex.: fit, fdescribe).
  config.filter_run_when_matching :focus

  # Guarda o status de cada exemplo para "rspec --only-failures" / "--next-failure".
  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"

  # Desliga a sintaxe antiga (monkey patching de "should" em todo objeto).
  config.disable_monkey_patching!

  # Ordem aleatória: revela testes que dependem uns dos outros. A semente aparece na
  # saída; repita uma ordem com "rspec --seed 1234".
  config.order = :random
  Kernel.srand config.seed
end
