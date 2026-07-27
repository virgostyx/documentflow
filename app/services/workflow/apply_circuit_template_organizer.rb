# frozen_string_literal: true

module Workflow
  class ApplyCircuitTemplateOrganizer < ApplicationService
    workflow_steps Actions::ValidateTemplateHasSteps,
                   Actions::ValidateTemplateHasSignStep,
                   Actions::CloneCircuitTemplateSteps
  end
end
