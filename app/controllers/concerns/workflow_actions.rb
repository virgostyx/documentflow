# frozen_string_literal: true

module WorkflowActions
  extend ActiveSupport::Concern

  def approve
    handle_workflow_action(
      organizer: Workflow::ApproveStepOrganizer,
      organizer_params: { step: @workflow_step, current_user: current_user },
      success_message: "Step approved successfully."
    )
  end

  def reject
    handle_workflow_action(
      organizer: Workflow::RejectStepOrganizer,
      organizer_params: { step: @workflow_step, current_user: current_user, reason: params[:reason] },
      success_message: "Step rejected successfully."
    )
  end

  private

  def handle_workflow_action(organizer:, organizer_params:, success_message:)
    result = organizer.call(**organizer_params)

    redirect_target = entity_document_path(current_entity, @workflow_step.document)

    if result.success?
      redirect_to redirect_target, notice: success_message
    else
      redirect_to redirect_target, alert: result.message
    end
  end
end
