# frozen_string_literal: true

module Documents
  class DocumentStatusBadgeComponent < ViewComponent::Base
    COLORS = {
      "draft" => :gray,
      "in_progress" => :info,
      "signed" => :primary,
      "finalized" => :success,
      "cancelled" => :danger
    }.freeze

    def initialize(status:, archived_from_email: false)
      @status = status
      @archived_from_email = archived_from_email
    end

    private

    attr_reader :status

    def archived_from_email?
      @archived_from_email
    end

    def color
      archived_from_email? ? :info : COLORS.fetch(status, :gray)
    end

    def label
      archived_from_email? ? "Archived from Outlook" : status.titleize
    end
  end
end
