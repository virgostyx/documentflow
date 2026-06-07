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

    def initialize(status:)
      @status = status
    end

    private

    attr_reader :status

    def color
      COLORS.fetch(status, :gray)
    end

    def label
      status.titleize
    end
  end
end
