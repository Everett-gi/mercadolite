# Os filtros da vitrine como um objeto de formulário (form object). Ele não tem tabela:
# usa só as partes do Active Model de que precisa (atributos tipados e validações).
#
# Tudo o que chega aqui vem da URL, portanto do usuário, e não é confiável. Cada
# atributo é convertido para o seu tipo, validado e só então vira consulta.
class ProductSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  PER_PAGE = 12
  MAX_QUERY_LENGTH = 100

  # Lista FECHADA de ordenações. O valor da URL é só a CHAVE: o SQL de ORDER BY vem
  # daqui, nunca do texto do usuário (ORDER BY não aceita parâmetro ligado, então
  # interpolar o parâmetro seria SQL injection).
  SORTS = {
    "recentes" => { created_at: :desc },
    "menor_preco" => { price_cents: :asc },
    "maior_preco" => { price_cents: :desc },
    "nome" => { name: :asc }
  }.freeze
  DEFAULT_SORT = "recentes"

  # Atributos tipados: o Active Model converte a string da URL para o tipo declarado
  # ("2" => 2, "1" => true, "abc" => nil para :integer).
  attribute :q, :string
  attribute :vendor_id, :integer
  attribute :min_price, :string
  attribute :max_price, :string
  attribute :in_stock, :boolean, default: false
  attribute :sort, :string, default: DEFAULT_SORT
  attribute :page, :integer, default: 1

  validates :q, length: { maximum: MAX_QUERY_LENGTH }
  validates :sort, inclusion: { in: SORTS.keys }
  validate :prices_must_be_valid

  # @return [ActiveRecord::Relation<Product>] produtos filtrados e ordenados (sem paginar)
  def results
    return Product.none if invalid?

    scope = Product.active.includes(:vendor, :inventory).with_attached_images
    scope = scope.matching(q.strip) if q.present?
    scope = scope.where(vendor_id:) if vendor_id.present?
    scope = scope.where(price_cents: min_price_cents..) if min_price_cents
    scope = scope.where(price_cents: ..max_price_cents) if max_price_cents
    scope = scope.in_stock if in_stock
    # :id no fim desempata: sem ele, produtos com o mesmo preço poderiam trocar de
    # posição entre uma página e outra.
    scope.order(SORTS.fetch(sort)).order(:id)
  end

  # @return [Integer, nil]
  def min_price_cents = Brl.parse_cents(min_price)

  # @return [Integer, nil]
  def max_price_cents = Brl.parse_cents(max_price)

  # Os filtros atuais, já normalizados, para montar links (paginação) sem repassar
  # parâmetros crus da URL.
  #
  # @return [Hash{Symbol => Object}]
  def to_params
    { q:, vendor_id:, min_price:, max_price:, sort: }
      .merge(in_stock: in_stock ? "1" : nil)
      .compact_blank
  end

  # Há algum filtro além da ordenação? (a view mostra "limpar filtros")
  #
  # @return [Boolean]
  def filtered?
    to_params.except(:sort).any?
  end

  private

  def prices_must_be_valid
    errors.add(:min_price, :invalid_price) if min_price.present? && min_price_cents.nil?
    errors.add(:max_price, :invalid_price) if max_price.present? && max_price_cents.nil?
    return unless min_price_cents && max_price_cents && min_price_cents > max_price_cents

    errors.add(:max_price, :less_than_min_price)
  end
end
