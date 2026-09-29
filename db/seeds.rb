# Dados de exemplo para DESENVOLVIMENTO:  bin/rails db:seed
#
# Idempotente: rodar duas vezes não duplica nada (find_or_create_by! procura antes de
# criar). As imagens são geradas aqui mesmo com a libvips (um quadro de cor sólida), para
# não depender de arquivos baixados da internet.
abort("Os seeds são só para desenvolvimento.") if Rails.env.production?

require "vips"

# Gera um PNG de cor sólida, em memória.
#
# @param rgb [Array(Integer, Integer, Integer)]
# @return [StringIO]
def solid_png(rgb)
  image = Vips::Image.black(800, 800).new_from_image(rgb).cast(:uchar)
  StringIO.new(image.write_to_buffer(".png"))
end

CATALOG = {
  "Ateliê da Serra" => {
    description: "Cerâmica feita à mão em pequenos lotes.",
    color: [ 180, 110, 80 ],
    products: [
      [ "Caneca de cerâmica esmaltada", 4990, 12, "Caneca de 300 ml, esmalte verde-musgo.\nPode ir ao micro-ondas." ],
      [ "Jogo de pratos rasos (4 un.)", 18900, 3, "Pratos de 26 cm, acabamento fosco." ],
      [ "Vaso de barro pequeno", 3500, 0, "Ideal para suculentas. Acompanha prato." ],
      [ "Bule para café", 12950, 5, "Capacidade de 1 litro, com coador de pano." ]
    ]
  },
  "Café do Vale" => {
    description: "Torrefação artesanal de cafés especiais do Sul de Minas.",
    color: [ 90, 60, 40 ],
    products: [
      [ "Café especial em grãos 250 g", 3890, 40, "Notas de chocolate e caramelo. Torra média." ],
      [ "Café moído para coado 500 g", 5490, 25, "Moagem média, torra média-escura." ],
      [ "Kit degustação (3 origens)", 9900, 8, "Três pacotes de 100 g de origens diferentes." ],
      [ "Coador de pano reutilizável", 1590, 0, "Algodão cru. Lave só com água." ],
      [ "Moedor manual de café", 21900, 4, "Mó cônica de cerâmica, 30 níveis de moagem." ]
    ]
  },
  "Papelaria Origami" => {
    description: "Cadernos e papéis para quem gosta de escrever à mão.",
    color: [ 60, 120, 160 ],
    products: [
      [ "Caderno pontilhado A5", 4200, 30, "160 páginas, papel 120 g/m²." ],
      [ "Caneta tinteiro de iniciante", 7990, 10, "Pena média, com conversor." ],
      [ "Estojo de lona", 2990, 15, "Dois compartimentos, zíper de metal." ],
      [ "Bloco de papel kraft", 1890, 0, "50 folhas A4, 90 g/m²." ],
      [ "Marcadores de página (10 un.)", 990, 60, "Ímãs de papelão reciclado." ],
      [ "Agenda semanal 2027", 5990, 20, "Capa dura, uma semana por página dupla." ]
    ]
  }
}.freeze

CATALOG.each do |vendor_name, data|
  vendor = Vendor.find_or_create_by!(name: vendor_name) do |new_vendor|
    new_vendor.description = data[:description]
  end

  data[:products].each_with_index do |(name, price_cents, quantity, description), index|
    product = vendor.products.find_or_create_by!(name:) do |new_product|
      new_product.price_cents = price_cents
      new_product.description = description
    end
    product.inventory.update!(quantity:)

    next if product.images.attached?

    # Cada produto recebe um tom um pouco diferente da cor do vendedor.
    shade = data[:color].map { |channel| (channel + (index * 18)).clamp(0, 255) }
    product.images.attach(io: solid_png(shade), filename: "#{product.id}.png", content_type: "image/png")
  end
end

puts "Seeds: #{Vendor.count} vendedores, #{Product.count} produtos."
