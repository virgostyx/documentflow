# frozen_string_literal: true

module Ui
  class ButtonComponentPreview < ViewComponent::Preview
    def default
      render(Ui::ButtonComponent.new(href: "#")) { "Create document" }
    end

    def secondary
      render(Ui::ButtonComponent.new(href: "#", variant: :secondary)) { "Cancel" }
    end

    def danger
      render(Ui::ButtonComponent.new(href: "#", variant: :danger, method: :delete)) { "Delete" }
    end
  end
end
