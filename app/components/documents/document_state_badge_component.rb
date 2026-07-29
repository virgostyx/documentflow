# frozen_string_literal: true

module Documents
  # Direction-aware status badge for a table row that may mix outgoing and
  # incoming (routed) documents, such as the merged ToDo/Waiting/Info tables.
  class DocumentStateBadgeComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    private

    attr_reader :document
  end
end
