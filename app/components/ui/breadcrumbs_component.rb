# frozen_string_literal: true

module Ui
  class BreadcrumbsComponent < ViewComponent::Base
    def initialize(items:)
      @items = items
    end

    def render?
      @items.present?
    end
  end
end
