# frozen_string_literal: true

# Base controller class for the Mission Control Jobs engine (see
# config/initializers/mission_control_jobs.rb) - restricts the background
# jobs dashboard to super admins instead of the gem's default HTTP Basic Auth.
class MissionControlAuthController < ApplicationController
  before_action :require_super_admin

  private

  def require_super_admin
    return if current_user&.super_admin?

    # `main_app.` avoids resolving to the mission_control-jobs engine's own
    # (isolated) root route, which would otherwise redirect back into /jobs
    # and loop.
    redirect_to main_app.root_path, alert: "You are not authorized to perform this action."
  end
end
