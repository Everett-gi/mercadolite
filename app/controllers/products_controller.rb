# Vitrine pública: lista com busca/filtros e página de detalhe.
class ProductsController < ApplicationController
  # GET / e GET /products?q=...&vendor_id=...&min_price=...&page=...
  def index
    @search = ProductSearch.new(search_params)
    @vendors = Vendor.order(:name)

    results = @search.results
    @pagination = Pagination.build(
      requested_page: @search.page,
      per_page: ProductSearch::PER_PAGE,
      total_count: results.count
    )
    @products = results.offset(@pagination.offset).limit(@pagination.per_page)
  end

  # GET /products/:id
  # Produto inativo (ou inexistente) => RecordNotFound => 404. Não revelamos se ele existe.
  def show
    @product = Product.active.includes(:vendor, :inventory).with_attached_images.find(params[:id])
  end

  private

  # Strong parameters: só estas chaves passam; qualquer outra da URL é descartada.
  def search_params
    params.permit(:q, :vendor_id, :min_price, :max_price, :in_stock, :sort, :page)
  end
end
