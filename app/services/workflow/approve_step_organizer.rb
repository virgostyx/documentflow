# frozen_string_literal: true

module Workflow
  class ApproveStepOrganizer < ApplicationService
    workflow_steps Actions::ValidateActorCanApprove,
                   Actions::ValidateSignerHasSignatureImage,
                   Actions::ValidateStepUpChallenge,
                   Actions::ValidateDispatchMessage,
                   Actions::ApproveStep,
                   Actions::SetDispatchPreference,
                   Actions::SetDispatchMessage,
                   Actions::SetDispatchSubject,
                   Actions::AdvanceWorkflow,
                   Actions::NotifyNextActor,
                   Actions::BroadcastSidebarToNextActor,
                   Actions::BroadcastWorkflowStepsToNextActor
  end
end
