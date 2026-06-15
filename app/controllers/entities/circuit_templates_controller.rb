# frozen_string_literal: true

module Entities
  class CircuitTemplatesController < ApplicationController
    include EntityScoped

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

      if @circuit_template.save
        redirect_to entity_circuit_templates_path(current_entity), notice: "Circuit template created successfully."
      else
        flash.now[:alert] = @circuit_template.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @circuit_template
    end

    def update
      authorize @circuit_template

      if @circuit_template.update(circuit_template_params)
        redirect_to entity_circuit_templates_path(current_entity), notice: "Circuit template updated successfully."
      else
        flash.now[:alert] = @circuit_template.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
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
