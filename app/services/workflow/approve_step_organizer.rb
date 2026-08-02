# frozen_string_literal: true

module Workflow
  class ApproveStepOrganizer < ApplicationService
    workflow_steps Actions::ValidateActorCanApprove,
                   Actions::ValidateSignerHasSignatureImage,
                   Actions::ValidateStepUpChallenge,
                   Actions::ApproveStep,
                   Actions::SetDispatchPreference,
                   Actions::AdvanceWorkflow,
                   Actions::NotifyNextActor,
                   Actions::BroadcastSidebarToNextActor
  end
end
