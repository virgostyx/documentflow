# frozen_string_literal: true

module Ui
  class EmptyStateComponentPreview < ViewComponent::Preview
    def default
      render(Ui::EmptyStateComponent.new(
        title: "No documents found",
        description: "Create a document to start a validation workflow."
      ))
    end

    def with_action
      render(Ui::EmptyStateComponent.new(
        title: "No documents found",
        description: "Create a document to start a validation workflow."
      )) do |empty_state|
        empty_state.with_action { render(Ui::ButtonComponent.new(href: "#")) { "New document" } }
      end
    end
  end
end
