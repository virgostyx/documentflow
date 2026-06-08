# frozen_string_literal: true

class ReminderJob < ApplicationJob
  queue_as :default

  def perform
    Document.in_progress.find_each do |document|
      step = document.current_step
      next unless step&.actor

      NotificationJob.perform_later(step.actor.id, "action_required", document.id)
    end
  end
end
