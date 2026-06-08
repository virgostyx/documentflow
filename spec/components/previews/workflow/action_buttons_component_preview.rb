# frozen_string_literal: true

module Workflow
  class ActionButtonsComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def as_current_step_actor
      document = workflow_document
      visa_actor = User.find_by!(email: "visa.actor@preview.example.com")

      render(Workflow::ActionButtonsComponent.new(document: document, current_user: visa_actor))
    end

    def as_other_member
      document = workflow_document

      render(Workflow::ActionButtonsComponent.new(document: document, current_user: document.created_by))
    end

    private

    def workflow_document
      preview_document(subject: "Supplier agreement (preview - actions)", status: "in_progress", with_workflow: true)
    end
  end
end
