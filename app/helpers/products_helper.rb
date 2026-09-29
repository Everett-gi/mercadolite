# Helpers: funções disponíveis nas views, para tirar lógica de formatação do HTML.
module ProductsHelper
  # @param cents [Integer] ex.: 4990
  # @return [String] ex.: "R$ 49,90" (formato do locale pt-BR)
  def price_tag(cents)
    number_to_currency(Brl.from_cents(cents))
  end

  # Opções do <select> de ordenação: [["Mais recentes", "recentes"], ...]
  #
  # @return [Array<Array(String, String)>]
  def sort_options
    [
      [ "Mais recentes", "recentes" ],
      [ "Menor preço", "menor_preco" ],
      [ "Maior preço", "maior_preco" ],
      [ "Nome (A–Z)", "nome" ]
    ]
  end
end
