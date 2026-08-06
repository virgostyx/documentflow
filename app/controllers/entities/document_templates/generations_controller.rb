# frozen_string_literal: true

module Entities
  module DocumentTemplates
    class GenerationsController < ApplicationController
      include EntityScoped

      before_action :set_document_template

      def new
        authorize @document_template, :show?

        @document = current_entity.documents.new(
          department_id: @document_template.department_id || current_entity_user.primary_department&.id,
          sender_token: @document_template.default_sender_token,
          addressee_token: @document_template.default_addressee_token,
          document_date: Date.current
        )
        @field_values = {}
        @cc_party_tokens = []
      end

      def create
        authorize @document_template, :show?

        result = ::Templates::GenerateDocumentOrganizer.call(
          entity: current_entity,
          current_user: current_user,
          document_template: @document_template,
          field_values: field_values_params,
          document_params: document_params,
          cc_party_tokens: cc_party_tokens_params,
          annex_files: annex_files_params
        )

        if result.success?
          redirect_to entity_document_path(current_entity, result.document), notice: "Document generated successfully."
        else
          @document = current_entity.documents.new(document_params)
          @field_values = field_values_params
          @cc_party_tokens = cc_party_tokens_params
          flash.now[:alert] = result.message
          render :new, status: :unprocessable_content
        end
      end

      private

      def set_document_template
        @document_template = current_entity.document_templates.find(params[:document_template_id])
      end

      def document_params
        params.require(:document).permit(
          :document_date, :department_id, :expects_response, :response_deadline, :sender_token, :addressee_token
        )
      end

      def field_values_params
        return {} unless params[:field_values]

        params.require(:field_values).permit(*@document_template.document_template_fields.pluck(:tag_name)).to_h
      end

      def cc_party_tokens_params
        params.require(:document).permit(cc_party_tokens: []).fetch(:cc_party_tokens, [])
      end

      def annex_files_params
        params.require(:document).permit(annexes: []).fetch(:annexes, [])
      end
    end
  end
end
