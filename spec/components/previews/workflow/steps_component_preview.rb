# frozen_string_literal: true

module Workflow
  class StepsComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def default
      document = preview_document(subject: "Supplier agreement (preview - steps)", status: "in_progress", with_workflow: true)
      render(Workflow::StepsComponent.new(document: document, current_user: document.created_by))
    end
  end
end
