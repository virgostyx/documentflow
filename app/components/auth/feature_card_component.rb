# frozen_string_literal: true

module Auth
  class FeatureCardComponent < ViewComponent::Base
    attr_reader :icon, :title, :description

    def initialize(icon:, title:, description:)
      @icon = icon
      @title = title
      @description = description
    end
  end
end
