# frozen_string_literal: true

module Ui
  class PageHeaderComponentPreview < ViewComponent::Preview
    def default
      render(Ui::PageHeaderComponent.new(
        title: "Documents",
        description: "Preview Entity",
        back_path: "#",
        back_text: "Preview Entity"
      ))
    end

    def without_back_link
      render(Ui::PageHeaderComponent.new(title: "Dashboard", description: "Welcome back"))
    end
  end
end
