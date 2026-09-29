# Carrinho de compras. Nesta fase ele é anônimo: a sessão do navegador guarda o id dele
# (veja o concern CurrentCart). Na fase 3, o carrinho passa a ter um dono.
class Cart < ApplicationRecord
  # Carrinho sem nenhuma alteração há mais que isso é apagado pelo PurgeAbandonedCartsJob.
  ABANDONED_AFTER = 30.days

  # class_name: o nome da associação (items) é diferente do nome da classe (CartItem).
  # dependent: :delete_all — um DELETE só para os itens (o banco também tem ON DELETE CASCADE).
  has_many :items, class_name: "CartItem", dependent: :delete_all

  # Range sem início (...data): "updated_at < data", ou seja, parados antes da data.
  scope :abandoned, -> { where(updated_at: ...ABANDONED_AFTER.ago) }

  # Acrescenta unidades de um produto. Se ele já está no carrinho, SOMA à linha existente.
  #
  # @param product [Product]
  # @param quantity [Integer] unidades a acrescentar (já validadas pelo chamador)
  # @param retried [Boolean] uso interno: se esta chamada já é a nova tentativa
  # @return [CartItem] o item; se não foi salvo, item.errors diz o motivo
  def add(product, quantity, retried: false)
    item = items.find_or_initialize_by(product:)
    item.quantity = item.quantity.to_i + quantity
    item.save
    item
  rescue ActiveRecord::RecordNotUnique
    # Duas requisições ao mesmo tempo tentaram criar a mesma linha e o índice único barrou
    # a segunda. Na nova tentativa, a linha já existe e a quantidade é somada a ela.
    raise if retried

    add(product, quantity, retried: true)
  end

  # As linhas com tudo o que a tela precisa carregado de uma vez (sem N+1), na ordem em que
  # foram adicionadas.
  #
  # @return [ActiveRecord::Relation<CartItem>]
  def lines
    items.includes(product: [ :vendor, :inventory, { images_attachments: :blob } ]).order(:created_at, :id)
  end

  # Total de unidades (o número do ícone do carrinho).
  #
  # @return [Integer]
  def items_count
    items.sum(:quantity)
  end

  # Subtotal só do que pode ser comprado agora, sempre com o preço atual do banco.
  #
  # @param lines [Enumerable<CartItem>] as linhas já carregadas (evita consultar de novo)
  # @return [Integer] em centavos
  def subtotal_cents(lines = self.lines)
    lines.select(&:purchasable?).sum(&:line_total_cents)
  end
end
