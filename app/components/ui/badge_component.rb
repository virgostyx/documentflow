# frozen_string_literal: true

module Ui
  class BadgeComponent < ViewComponent::Base
    COLORS = {
      gray: "bg-gray-100 text-gray-700",
      primary: "bg-primary-100 text-primary-700",
      success: "bg-success-100 text-success-700",
      warning: "bg-warning-100 text-warning-700",
      danger: "bg-danger-100 text-danger-700",
      info: "bg-info-100 text-info-700"
    }.freeze

    def initialize(color: :gray)
      @color = color
    end

    def color_classes
      COLORS[@color] || COLORS[:gray]
    end
  end
end
