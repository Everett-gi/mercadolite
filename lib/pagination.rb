# Paginação como valor imutável (Data, do Ruby 3.2+): parecido com uma struct do C cujos
# campos são const. Função PURA: não sabe nada de banco; só faz as contas.
#
#   pagination = Pagination.build(requested_page: 3, per_page: 12, total_count: 30)
#   pagination.page        # => 3
#   pagination.offset      # => 24  (pula 24 registros)
#   pagination.total_pages # => 3
Pagination = Data.define(:page, :per_page, :total_count) do
  # Cria a paginação a partir de uma página PEDIDA (vinda da URL, portanto não confiável).
  # A página é forçada para o intervalo válido: "?page=999999999" vira a última página, e
  # nunca produz um OFFSET gigante no SQL.
  #
  # @param requested_page [Integer, nil] página pedida (nil ou inválida => 1)
  # @param per_page [Integer] itens por página (> 0)
  # @param total_count [Integer] total de itens (>= 0)
  # @return [Pagination]
  def self.build(requested_page:, per_page:, total_count:)
    raise ArgumentError, "per_page deve ser positivo" unless per_page.positive?
    raise ArgumentError, "total_count não pode ser negativo" if total_count.negative?

    last_page = pages_for(total_count, per_page)
    new(page: requested_page.to_i.clamp(1, last_page), per_page:, total_count:)
  end

  # Divisão inteira arredondando para cima; no mínimo 1 página (mesmo com 0 itens).
  #
  # @return [Integer]
  def self.pages_for(total_count, per_page)
    [ (total_count + per_page - 1) / per_page, 1 ].max
  end

  # @return [Integer]
  def total_pages = self.class.pages_for(total_count, per_page)

  # Quantos registros pular (o OFFSET do SQL).
  # @return [Integer]
  def offset = (page - 1) * per_page

  # @return [Integer, nil] nil quando já é a primeira página
  def previous_page = page > 1 ? page - 1 : nil

  # @return [Integer, nil] nil quando já é a última página
  def next_page = page < total_pages ? page + 1 : nil
end
