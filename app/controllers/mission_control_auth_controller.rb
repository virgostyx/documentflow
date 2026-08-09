# frozen_string_literal: true

# Base controller class for the Mission Control Jobs engine (see
# config/initializers/mission_control_jobs.rb) - restricts the background
# jobs dashboard to super admins instead of the gem's default HTTP Basic Auth.
class MissionControlAuthController < ApplicationController
  include SuperAdminAuthorization
end
