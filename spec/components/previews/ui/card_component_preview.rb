# frozen_string_literal: true

module Ui
  class CardComponentPreview < ViewComponent::Preview
    def default
      render(Ui::CardComponent.new) do |card|
        card.with_header { "Card title" }
        "Card body content goes here."
      end
    end

    def with_footer
      render(Ui::CardComponent.new) do |card|
        card.with_header { "Card title" }
        card.with_footer { "Footer content" }
        "Card body content goes here."
      end
    end
  end
end
