# frozen_string_literal: true

# Base class for all service actions
# Actions are atomic steps of an Organizer
class ApplicationAction
  extend LightService::Action

  # Usage: fail_with!(ctx, "Error message", :error_key)
  def self.fail_with!(ctx, message, error_key = :error)
    ctx.fail!(message)
    ctx[error_key] = message
    ctx
  end

  # Usage: succeed_with!(ctx, "Success message", result: data)
  def self.succeed_with!(ctx, message, data = {})
    ctx.message = message
    data.each { |key, value| ctx[key] = value }
    ctx
  end

  def self.log_action(ctx, message, level: :info)
    logger = ctx[:logger] || Rails.logger
    return unless logger.present?

    logger.send(level, "[#{name}] #{message}")
  end

  # Usage: handle_error(ctx, error, "Message intended for the user")
  def self.handle_error(ctx, error, user_message = nil)
    log_action(ctx, "Error: #{error.message}", level: :error)

    message = user_message || "An error occurred: #{error.message}"
    fail_with!(ctx, message)
  end
end
