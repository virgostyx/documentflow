# frozen_string_literal: true

module Documents
  class FileVersionListComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    def versions
      document.document_file_versions.ordered.reverse_order
    end

    def render?
      versions.any?
    end

    private

    attr_reader :document
  end
end
