# frozen_string_literal: true

# Restricts a controller to super admins only, redirecting everyone else back
# to the app root with an authorization alert. Shared by the mission_control-jobs
# gate (see mission_control_auth_controller.rb) and the /admin panel.
module SuperAdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :require_super_admin
  end

  private

  def require_super_admin
    return if current_user&.super_admin?

    # `main_app.` avoids resolving to a mounted engine's own (isolated) root
    # route when this before_action runs inside one (e.g. mission_control-jobs),
    # which would otherwise redirect back into the engine and loop.
    redirect_to main_app.root_path, alert: "You are not authorized to perform this action."
  end
end
