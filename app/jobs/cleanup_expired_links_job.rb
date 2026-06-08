# frozen_string_literal: true

class CleanupExpiredLinksJob < ApplicationJob
  queue_as :default

  def perform
    SharedLink.expired.destroy_all
  end
end
