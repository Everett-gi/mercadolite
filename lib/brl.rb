# Funções PURAS para valores em reais (BRL). Não acessam banco, rede nem Rails: recebem
# dados e devolvem dados, e por isso são fáceis de testar (spec/lib/brl_spec.rb).
#
# O dinheiro circula pelo sistema como Integer em CENTAVOS. Só vira texto na exibição.
module Brl
  # Até 7 dígitos de reais e, opcionalmente, vírgula ou ponto com 1 ou 2 dígitos de
  # centavos. Separador de milhar NÃO é aceito: "1.234" seria ambíguo (mil duzentos e
  # trinta e quatro reais, ou um real e vinte e três centavos?), então é recusado.
  PRICE_PATTERN = /\A(\d{1,7})(?:[.,](\d{1,2}))?\z/

  # Converte o texto digitado por uma pessoa em centavos.
  #
  # @param text [String, nil] ex.: "49,90", "49.9", "50", " 12,5 "
  # @return [Integer, nil] ex.: 4990, 4990, 5000, 1250; nil se o texto for inválido
  def self.parse_cents(text)
    match = PRICE_PATTERN.match(text.to_s.strip)
    return nil if match.nil?

    reais, cents = match.captures
    # ljust completa à direita: "5" (de "12,5") vira "50" centavos, não 5.
    (reais.to_i * 100) + cents.to_s.ljust(2, "0").to_i
  end

  # Converte centavos em reais, sem passar por float.
  #
  # @param cents [Integer] ex.: 4990
  # @return [BigDecimal] ex.: 49.9 (decimal exato)
  def self.from_cents(cents)
    BigDecimal(cents) / 100
  end
end
