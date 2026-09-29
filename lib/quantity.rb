# Função PURA que interpreta uma quantidade digitada/enviada pelo navegador.
#
# Estrita de propósito: a conversão do Active Model (to_i) transformaria "abc" em 0 e
# "2abc" em 2 (lição da fase 1). Aqui, ou o texto é um inteiro limpo dentro do intervalo,
# ou o resultado é nil — e quem chama mostra uma mensagem de erro.
module Quantity
  # Só dígitos, sem sinal, sem espaço no meio, no máximo 3 (evita números gigantes).
  PATTERN = /\A\d{1,3}\z/

  # @param text [String, Integer, nil] ex.: "3", " 3 ", 3
  # @param max [Integer] maior quantidade aceita (inclusive)
  # @return [Integer, nil] a quantidade, ou nil se inválida ou fora de 1..max
  def self.parse(text, max:)
    raise ArgumentError, "max deve ser positivo" unless max.positive?

    digits = text.to_s.strip
    return nil unless PATTERN.match?(digits)

    value = Integer(digits, 10) # base 10 explícita: "08" é 8, e não octal inválido
    value.between?(1, max) ? value : nil
  end
end
