# frozen_string_literal: true

module Ui
  class DefinitionListComponent < ViewComponent::Base
    renders_many :items, "ItemComponent"

    class ItemComponent < ViewComponent::Base
      attr_reader :term, :badge

      def initialize(term:, badge: nil)
        @term = term
        @badge = badge
      end

      def call
        content
      end
    end
  end
end
