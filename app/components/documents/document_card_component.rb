# frozen_string_literal: true

module Documents
  class DocumentCardComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @current_user = current_user
    end

    private

    attr_reader :document, :current_user
  end
end
