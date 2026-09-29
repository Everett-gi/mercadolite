# Carrinho de compras. Tem dois estados (veja o concern CurrentCart):
#
# - de visitante: user_id nulo; a sessão do navegador guarda o id dele;
# - de usuário: pertence a uma conta (no máximo um por conta) e é achado por ela.
#
# No login, o carrinho de visitante é "reivindicado" pela conta (Cart.claim).
class Cart < ApplicationRecord
  # Carrinho sem nenhuma alteração há mais que isso é apagado pelo PurgeAbandonedCartsJob.
  ABANDONED_AFTER = 30.days

  # class_name: o nome da associação (items) é diferente do nome da classe (CartItem).
  # dependent: :delete_all — um DELETE só para os itens (o banco também tem ON DELETE CASCADE).
  has_many :items, class_name: "CartItem", dependent: :delete_all
  # optional: true — carrinho de visitante não tem dono.
  belongs_to :user, optional: true

  # Range sem início (...data): "updated_at < data", ou seja, parados antes da data.
  scope :abandoned, -> { where(updated_at: ...ABANDONED_AFTER.ago) }
  # Só carrinhos sem dono. A sessão de um visitante só pode apontar para um destes.
  scope :guest, -> { where(user_id: nil) }

  # Entrega o carrinho de visitante a quem acabou de entrar. Se a conta ainda não tem
  # carrinho, este passa a ser dela. Se já tem, os itens são somados ao dela e este é apagado.
  #
  # @param guest_cart [Cart, nil] o carrinho de visitante da sessão, se houver
  # @param user [User]
  # @param retried [Boolean] uso interno: se esta chamada já é a nova tentativa
  # @return [Cart, nil] o carrinho da conta, se ela tiver um
  def self.claim(guest_cart, user, retried: false)
    return user.cart if guest_cart.nil?

    transaction do
      if (own = user.cart)
        guest_cart.items.includes(:product).each { |item| own.merge_item(item.product, item.quantity) }
        guest_cart.destroy!
        own
      else
        guest_cart.update!(user:)
        guest_cart
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # Dois logins da mesma conta ao mesmo tempo: o outro deu um carrinho à conta primeiro
    # (o índice único de carts.user_id barrou este). Na nova tentativa, os itens são somados.
    raise if retried

    claim(guest_cart.reload, user.reload, retried: true)
  end

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

  # Soma unidades vindas de outro carrinho, limitando ao máximo por linha e ao estoque atual.
  # Produto fora de venda não entra (a validação do CartItem recusa e o item é descartado).
  #
  # @param product [Product]
  # @param quantity [Integer]
  # @return [Boolean] se a linha foi gravada
  def merge_item(product, quantity)
    # CartItem direto, pelo cart_id (e não items.find_or_initialize_by): uma linha recusada
    # não fica pendurada, sem salvar, na lista de itens deste objeto em memória.
    item = CartItem.find_or_initialize_by(cart_id: id, product:)
    item.quantity = [ item.quantity.to_i + quantity, CartItem::MAX_QUANTITY, product.stock_quantity ].min
    item.quantity.positive? && item.save
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
