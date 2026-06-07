# frozen_string_literal: true

module Workflow
  class RejectStepOrganizer < ApplicationService
    workflow_steps Actions::ValidateActorCanReject,
                   Actions::RejectStep,
                   Actions::ReturnToPreviousStep,
                   Actions::NotifyPreviousActor
  end
end
