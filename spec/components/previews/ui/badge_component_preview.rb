# frozen_string_literal: true

module Ui
  class BadgeComponentPreview < ViewComponent::Preview
    def default
      render(Ui::BadgeComponent.new(color: :gray)) { "Draft" }
    end

    def success
      render(Ui::BadgeComponent.new(color: :success)) { "Finalized" }
    end

    def danger
      render(Ui::BadgeComponent.new(color: :danger)) { "Cancelled" }
    end
  end
end
