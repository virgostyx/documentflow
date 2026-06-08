# frozen_string_literal: true

module Workflow
  class StepComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def pending
      render(Workflow::StepComponent.new(step: workflow_document.workflow_steps.find_by(role: "VISA")))
    end

    def approved
      render(Workflow::StepComponent.new(step: workflow_document.workflow_steps.find_by(role: "RED")))
    end

    private

    def workflow_document
      preview_document(subject: "Supplier agreement (preview - workflow step)", status: "in_progress", with_workflow: true)
    end
  end
end
