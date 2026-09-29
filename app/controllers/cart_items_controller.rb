# Alterações no carrinho: adicionar, mudar a quantidade e remover.
#
# Segurança:
# - CSRF: todas são POST/PATCH/DELETE, e o Rails exige o token do formulário.
# - Rate limit: no máximo RATE_LIMIT alterações por minuto por IP; acima disso, 429.
# - Anti-IDOR: um item só é encontrado DENTRO do carrinho desta sessão.
# - Preço: o navegador envia só produto e quantidade; o preço vem sempre do banco.
class CartItemsController < ApplicationController
  RATE_LIMIT = 30

  rate_limit to: RATE_LIMIT, within: 1.minute

  # POST /cart_items   cart_item[product_id], cart_item[quantity]
  def create
    attrs = params.expect(cart_item: [ :product_id, :quantity ])
    # Produto inativo ou inexistente => 404 (e o carrinho nem é criado).
    product = Product.active.find(attrs[:product_id])
    quantity = Quantity.parse(attrs[:quantity], max: CartItem::MAX_QUANTITY)
    return reject(t(".invalid_quantity", max: CartItem::MAX_QUANTITY), product:) if quantity.nil?

    @item = current_cart!.add(product, quantity)
    if @item.errors.any?
      reject(@item.errors.full_messages.to_sentence, product:)
    else
      added(product, quantity)
    end
  end

  # PATCH /cart_items/:id   cart_item[quantity]
  def update
    item = find_item
    quantity = Quantity.parse(params.expect(cart_item: [ :quantity ])[:quantity], max: CartItem::MAX_QUANTITY)

    if quantity && item.update(quantity:)
      redirect_to cart_path, notice: t(".updated")
    else
      alert = quantity ? item.errors.full_messages.to_sentence : t(".invalid_quantity", max: CartItem::MAX_QUANTITY)
      redirect_to cart_path, alert:
    end
  end

  # DELETE /cart_items/:id
  def destroy
    find_item.destroy!
    redirect_to cart_path, notice: t(".removed")
  end

  private

  # Anti-IDOR: procura o item só entre os do carrinho desta sessão. O id de um item de
  # outra pessoa (ou de um item que não existe) dá o mesmo 404, sem revelar nada.
  #
  # @return [CartItem]
  def find_item
    raise ActiveRecord::RecordNotFound if current_cart.nil?

    current_cart.items.find(params[:id])
  end

  # Resposta de sucesso ao adicionar. Com Turbo (formulário da página do produto), atualiza
  # o contador e o aviso sem sair da página; sem Turbo, redireciona para o carrinho.
  #
  # A ordem importa: quem aceita qualquer formato (Accept: */*, como o curl) recebe o
  # PRIMEIRO declarado, então o HTML vem antes. O Turbo pede o stream explicitamente.
  def added(product, quantity)
    message = t(".added", count: quantity, product: product.name)
    respond_to do |format|
      format.html { redirect_to cart_path, notice: message }
      format.turbo_stream { flash.now[:notice] = message }
    end
  end

  # Resposta de erro ao adicionar (quantidade inválida, estoque insuficiente...).
  def reject(message, product:)
    respond_to do |format|
      format.html { redirect_to product_path(product), alert: message }
      format.turbo_stream do
        flash.now[:alert] = message
        render :create, status: :unprocessable_content
      end
    end
  end
end
