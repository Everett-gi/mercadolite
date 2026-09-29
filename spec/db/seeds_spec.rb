require "rails_helper"

# O db:prepare carrega os seeds sempre que cria o banco, em qualquer ambiente. Estes
# testes garantem que, fora do desenvolvimento, os seeds não gravam nada e não falham
# (um "abort" derrubaria o primeiro deploy, que roda db:prepare no bin/docker-entrypoint).
RSpec.describe "db/seeds.rb" do
  it "não grava dados fora do desenvolvimento" do
    expect { Rails.application.load_seed }
      .to output(/Seeds de demonstração ignorados \(ambiente: test\)/).to_stdout

    expect(Vendor.count).to eq(0)
    expect(Product.count).to eq(0)
  end

  it "também não faz nada (nem falha) em produção" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    expect { Rails.application.load_seed }
      .to output(/ignorados \(ambiente: production\)/).to_stdout
    expect(Product.count).to eq(0)
  end
end
