# frozen_string_literal: true

module Entities
  class EmailTemplatesController < ApplicationController
    include EntityScoped
    include SavesAndResponds

    before_action :set_email_template, only: %i[edit update destroy]

    def index
      authorize EmailTemplate.new(entity: current_entity)
      @email_templates = policy_scope(EmailTemplate).where(entity: current_entity).order(:name)
    end

    def new
      @email_template = current_entity.email_templates.new
      authorize @email_template
    end

    def create
      @email_template = current_entity.email_templates.new(email_template_params.merge(created_by: current_user))
      authorize @email_template

      save_and_respond(@email_template,
                        success_path: -> { edit_entity_email_template_path(current_entity, @email_template) },
                        success_message: "Email template created. Review the detected fields below.",
                        failure_template: :new) { @email_template.save }
    end

    def edit
      authorize @email_template
    end

    def update
      authorize @email_template

      save_and_respond(@email_template,
                        success_path: entity_email_templates_path(current_entity),
                        success_message: "Email template updated successfully.",
                        failure_template: :edit) { @email_template.update(email_template_params) }
    end

    def destroy
      authorize @email_template
      @email_template.destroy
      redirect_to entity_email_templates_path(current_entity), notice: "Email template deleted successfully."
    end

    private

    def set_email_template
      @email_template = current_entity.email_templates.find(params[:id])
    end

    def email_template_params
      params.require(:email_template).permit(
        :name, :department_id, :subject_template, :body_template,
        email_template_fields_attributes: %i[id label field_type required options_text]
      )
    end
  end
end
