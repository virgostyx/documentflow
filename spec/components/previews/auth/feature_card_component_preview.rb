# frozen_string_literal: true

module Auth
  class FeatureCardComponentPreview < ViewComponent::Preview
    def default
      render(Auth::FeatureCardComponent.new(
        icon: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
        title: "Multi-actor validation",
        description: "Each step is assigned to an identified actor."
      ))
    end
  end
end
