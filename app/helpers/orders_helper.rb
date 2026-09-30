# Formatação dos pedidos nas views.
module OrdersHelper
  STATUS_STYLES = {
    "pending" => "bg-amber-100 text-amber-800",
    "paid" => "bg-emerald-100 text-emerald-800",
    "shipped" => "bg-sky-100 text-sky-800",
    "canceled" => "bg-stone-200 text-stone-700",
    "refunding" => "bg-orange-100 text-orange-800",
    "refunded" => "bg-violet-100 text-violet-800"
  }.freeze

  # O status do pedido como uma etiqueta colorida, em português.
  #
  # @param order [Order]
  # @return [ActiveSupport::SafeBuffer]
  def order_status_badge(order)
    tag.span(Order.human_attribute_name("status.#{order.status}"),
             class: "rounded-full px-2.5 py-0.5 text-xs font-medium #{STATUS_STYLES.fetch(order.status)}")
  end
end
