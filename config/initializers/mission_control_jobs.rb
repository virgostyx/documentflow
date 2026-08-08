# frozen_string_literal: true

# Set directly on the MissionControl::Jobs module rather than via
# `config.mission_control.jobs.*` - the engine only syncs that config
# namespace into these module attributes during `before_initialize`, which
# runs before this (a regular) initializer, so setting it there is a no-op.
Rails.application.configure do
  MissionControl::Jobs.base_controller_class = "MissionControlAuthController"
  MissionControl::Jobs.http_basic_auth_enabled = false
end
