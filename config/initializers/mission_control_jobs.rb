# frozen_string_literal: true

# Set directly on the MissionControl::Jobs module rather than via
# `config.mission_control.jobs.*` - the engine only syncs that config
# namespace into these module attributes during `before_initialize`, which
# runs before this (a regular) initializer, so setting it there is a no-op.
Rails.application.configure do
  MissionControl::Jobs.base_controller_class = "MissionControlAuthController"
  MissionControl::Jobs.http_basic_auth_enabled = false
end

# Reskin the gem's blank-status message (defined in Ruby, not overridable via
# a view) to use DocumentFlow's empty-state component instead of its own
# Bulma-styled markup. Also add a status -> Ui::BadgeComponent color mapping,
# mirroring the gem's own `modifier_for_status` (which maps statuses to Bulma
# classes), for use in the overridden views.
Rails.application.config.to_prepare do
  MissionControl::Jobs::InterfaceHelper.module_eval do
    def blank_status_notice(message)
      render Ui::EmptyStateComponent.new(title: message)
    end

    def badge_color_for_status(status)
      case status.to_s
      when "failed" then :danger
      when "blocked" then :warning
      when "finished" then :success
      when "scheduled" then :info
      when "in_progress" then :primary
      else :gray
      end
    end
  end
end
