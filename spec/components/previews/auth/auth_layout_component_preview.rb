# frozen_string_literal: true

module Auth
  class AuthLayoutComponentPreview < ViewComponent::Preview
    def default
      render(Auth::AuthLayoutComponent.new(title: "Sign in", subtitle: "Welcome back to DocumentFlow")) do
        "Form fields go here."
      end
    end
  end
end
