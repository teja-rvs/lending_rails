class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  before_action :set_paper_trail_whodunnit
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :render_not_authorized

  private
    def pundit_user
      Current.user
    end

    def user_for_paper_trail
      Current.user&.id
    end

    def render_not_authorized
      redirect_to root_path, alert: "You are not authorized to access that area."
    end
end
