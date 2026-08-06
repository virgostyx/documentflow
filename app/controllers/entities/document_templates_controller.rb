# frozen_string_literal: true

module Entities
  class DocumentTemplatesController < ApplicationController
    include EntityScoped

    before_action :set_document_template, only: %i[edit update destroy]

    def index
      authorize DocumentTemplate.new(entity: current_entity)
      @document_templates = policy_scope(DocumentTemplate).where(entity: current_entity).order(:name)
    end

    def new
      @document_template = current_entity.document_templates.new
      authorize @document_template
    end

    def create
      @document_template = current_entity.document_templates.new(document_template_params.merge(created_by: current_user))
      authorize @document_template

      if @document_template.save
        redirect_to edit_entity_document_template_path(current_entity, @document_template),
                    notice: "Document template created. Review the detected fields below."
      else
        flash.now[:alert] = @document_template.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @document_template
    end

    def update
      authorize @document_template

      if @document_template.update(document_template_params)
        redirect_to entity_document_templates_path(current_entity), notice: "Document template updated successfully."
      else
        flash.now[:alert] = @document_template.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @document_template
      @document_template.destroy
      redirect_to entity_document_templates_path(current_entity), notice: "Document template deleted successfully."
    end

    private

    def set_document_template
      @document_template = current_entity.document_templates.find(params[:id])
    end

    def document_template_params
      params.require(:document_template).permit(
        :name, :department_id, :subject_template, :source_file, :circuit_template_id,
        :default_sender_token, :default_addressee_token,
        document_template_fields_attributes: %i[id label field_type required options_text]
      )
    end
  end
end
