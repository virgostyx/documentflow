# frozen_string_literal: true

module Entities
  class CircuitTemplatesController < ApplicationController
    include EntityScoped
    include SavesAndResponds

    before_action :set_circuit_template, only: %i[edit update destroy]

    def index
      authorize CircuitTemplate.new(entity: current_entity)
      @circuit_templates = policy_scope(CircuitTemplate).where(entity: current_entity).order(:name)
    end

    def new
      @circuit_template = current_entity.circuit_templates.new
      @circuit_template.circuit_template_steps.build(order: 1)
      authorize @circuit_template
    end

    def create
      @circuit_template = current_entity.circuit_templates.new(circuit_template_params)
      authorize @circuit_template

      save_and_respond(@circuit_template,
                        success_path: entity_circuit_templates_path(current_entity),
                        success_message: "Circuit template created successfully.",
                        failure_template: :new) { @circuit_template.save }
    end

    def edit
      authorize @circuit_template
    end

    def update
      authorize @circuit_template

      save_and_respond(@circuit_template,
                        success_path: entity_circuit_templates_path(current_entity),
                        success_message: "Circuit template updated successfully.",
                        failure_template: :edit) { @circuit_template.update(circuit_template_params) }
    end

    def destroy
      authorize @circuit_template
      @circuit_template.destroy
      redirect_to entity_circuit_templates_path(current_entity), notice: "Circuit template deleted successfully."
    end

    private

    def set_circuit_template
      @circuit_template = current_entity.circuit_templates.find(params[:id])
    end

    def circuit_template_params
      params.require(:circuit_template).permit(
        :name,
        circuit_template_steps_attributes: %i[id role order actor_id is_parallel parallel_group _destroy]
      )
    end
  end
end
