# frozen_string_literal: true

# Base controller class for the Mission Control Jobs engine (see
# config/initializers/mission_control_jobs.rb) - restricts the background
# jobs dashboard to super admins instead of the gem's default HTTP Basic Auth.
class MissionControlAuthController < ApplicationController
  before_action :require_super_admin

  private

  def require_super_admin
    redirect_to root_path, alert: "You are not authorized to perform this action." unless current_user&.super_admin?
  end
end
