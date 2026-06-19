# frozen_string_literal: true

module Documents
  class ThreadComponent < ViewComponent::Base
    def initialize(documents:, current_document:)
      @documents = documents
      @current_document = current_document
    end

    private

    attr_reader :documents, :current_document

    def current?(document)
      document == current_document
    end
  end
end
