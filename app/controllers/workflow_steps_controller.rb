# frozen_string_literal: true

class WorkflowStepsController < ApplicationController
  include EntityScoped
  include WorkflowActions

  before_action :set_document
  before_action :set_workflow_step, except: %i[create apply_template]

  def create
    @workflow_step = @document.workflow_steps.new(workflow_step_params)
    @workflow_step.order = @document.workflow_steps.maximum(:order).to_i + 1
    authorize @workflow_step

    if @workflow_step.save
      redirect_to entity_document_path(current_entity, @document), notice: "Step added to the validation circuit."
    else
      redirect_to entity_document_path(current_entity, @document), alert: @workflow_step.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @workflow_step

    if @workflow_step.update(workflow_step_params)
      redirect_to entity_document_path(current_entity, @document), notice: "Step updated successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: @workflow_step.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @workflow_step

    @workflow_step.destroy
    redirect_to entity_document_path(current_entity, @document), notice: "Step removed from the validation circuit."
  end

  def move_up
    authorize @workflow_step

    swap_with_adjacent_step(-1)
    redirect_to entity_document_path(current_entity, @document), notice: "Step moved up."
  end

  def move_down
    authorize @workflow_step

    swap_with_adjacent_step(1)
    redirect_to entity_document_path(current_entity, @document), notice: "Step moved down."
  end

  def apply_template
    authorize @document.workflow_steps.new, :apply_template?

    circuit_template = current_entity.circuit_templates.find(params[:circuit_template_id])
    result = Workflow::ApplyCircuitTemplateOrganizer.call(document: @document, circuit_template: circuit_template, current_user: current_user)

    if result.success?
      redirect_to entity_document_path(current_entity, @document), notice: "Circuit template applied successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: result.message
    end
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end

  def set_workflow_step
    @workflow_step = @document.workflow_steps.find(params[:id])
  end

  def workflow_step_params
    params.require(:workflow_step).permit(:role, :actor_id, :is_parallel, :parallel_group)
  end

  def swap_with_adjacent_step(direction)
    adjacent_step = @document.workflow_steps.find_by(order: @workflow_step.order + direction)
    return unless adjacent_step

    original_order = @workflow_step.order
    WorkflowStep.transaction do
      @workflow_step.update_column(:order, -1)
      adjacent_step.update_column(:order, original_order)
      @workflow_step.update_column(:order, original_order + direction)
    end
  end
end
