# frozen_string_literal: true

class WorkflowStepsController < ApplicationController
  include EntityScoped
  include WorkflowActions

  before_action :set_workflow_step

  private

  def set_workflow_step
    @workflow_step = current_entity.documents
                                   .find(params[:document_id])
                                   .workflow_steps
                                   .find(params[:id])
  end
end
