# frozen_string_literal: true

module Shared
  class HeaderComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def default
      render(Shared::HeaderComponent.new(current_user: preview_user("owner@preview.example.com")))
    end
  end
end
