# Produto do catálogo. Preço em centavos (Integer) e imagens no Active Storage.
class Product < ApplicationRecord
  MAX_NAME_LENGTH = 120
  MAX_DESCRIPTION_LENGTH = 5_000
  MAX_PRICE_CENTS = 100_000_000 # R$ 1.000.000,00 (a mesma regra está no banco)

  MAX_IMAGES = 5
  MAX_IMAGE_BYTES = 5.megabytes
  # SVG fica de fora de propósito: um SVG pode conter <script> e virar XSS.
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze

  belongs_to :vendor
  has_one :inventory, dependent: :destroy

  # Imagens guardadas pelo Active Storage (tabelas active_storage_*), com duas variantes
  # nomeadas. As variantes são geradas pela libvips na primeira vez que são pedidas.
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 400 ]
    attachable.variant :large, resize_to_limit: [ 1200, 1200 ]
  end

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
  validates :price_cents, numericality: {
    only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_PRICE_CENTS
  }
  validate :images_must_be_acceptable

  # Todo produto nasce com um registro de estoque (quantidade 0).
  before_validation :build_default_inventory, on: :create

  scope :active, -> { where(active: true) }
  scope :in_stock, -> { joins(:inventory).where(inventories: { quantity: 1.. }) }

  # Busca por texto no nome e na descrição, sem diferenciar maiúsculas (ILIKE) nem
  # acentos (unaccent). O termo vai como PARÂMETRO LIGADO (:pattern): o banco o trata
  # sempre como dado, nunca como SQL, então não há como injetar SQL por aqui.
  # sanitize_sql_like escapa os curingas do LIKE (% e _) digitados pela pessoa.
  #
  # @param term [String]
  # @return [ActiveRecord::Relation]
  def self.matching(term)
    pattern = "%#{sanitize_sql_like(term)}%"
    where(
      "unaccent(products.name) ILIKE unaccent(:pattern) " \
      "OR unaccent(products.description) ILIKE unaccent(:pattern)",
      pattern:
    )
  end

  # @return [BigDecimal] preço em reais, exato (sem float)
  def price
    Brl.from_cents(price_cents)
  end

  # @return [Boolean]
  def in_stock?
    inventory.present? && inventory.quantity.positive?
  end

  private

  def build_default_inventory
    build_inventory(quantity: 0) if inventory.nil?
  end

  # O Active Storage descobre o tipo real do arquivo pelos primeiros bytes (os "magic
  # numbers"), e não só pela extensão do nome: um .exe renomeado para .png é pego aqui.
  def images_must_be_acceptable
    return unless images.attached?

    if images.size > MAX_IMAGES
      errors.add(:images, :too_many, count: MAX_IMAGES)
    end

    images.each do |image|
      unless ALLOWED_IMAGE_TYPES.include?(image.blob.content_type)
        errors.add(:images, :invalid_type, filename: image.blob.filename.to_s)
      end
      if image.blob.byte_size > MAX_IMAGE_BYTES
        errors.add(:images, :too_large, filename: image.blob.filename.to_s,
                                         max_mb: MAX_IMAGE_BYTES / 1.megabyte)
      end
    end
  end
end
