class ApplicationController < ActionController::Base
  include CurrentCart
  # Autorização (Pundit): authorize, policy_scope e verify_authorized nos controllers.
  include Pundit::Authorization

  # Acesso negado pela policy responde como "não existe" (404): não revela a quem tenta
  # adivinhar ids que o registro existe.
  rescue_from Pundit::NotAuthorizedError do
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
