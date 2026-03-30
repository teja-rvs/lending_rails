class MissionControlAccessController < ApplicationController
  before_action :require_admin_user!

  private
    def require_admin_user!
      return if Current.user&.admin?

      redirect_to root_path, alert: "You are not authorized to access that area."
    end
end
