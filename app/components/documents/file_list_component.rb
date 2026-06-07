# frozen_string_literal: true

module Documents
  class FileListComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    private

    attr_reader :document
  end
end
