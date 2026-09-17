# frozen_string_literal: true

module Documents
  # A single row of the documents table. Deliberately self-contained (no
  # dependency on an ambient current_entity/current_user controller helper)
  # so it can be rendered identically from a real request (documents/_table)
  # or out-of-request from DocumentRowBroadcastJob.
  class RowComponent < ViewComponent::Base
    def initialize(document:, current_user:, list_scope: nil)
      @document = document
      @current_user = current_user
      @list_scope = list_scope
    end

    private

    attr_reader :document, :current_user, :list_scope

    def row_path
      document.incoming? ? entity_incoming_mail_path(document.entity, document) : entity_document_path(document.entity, document)
    end

    def preview_main_file_path
      preview_entity_document_main_file_path(document.entity, document)
    end

    def classify_form_path
      classify_form_entity_document_path(document.entity, document)
    end

    def reply_path
      new_entity_document_path(document.entity, reply_to: document.id)
    end

    def confirm_dismiss_waiting_path
      confirm_dismiss_waiting_entity_document_path(document.entity, document)
    end

    def dismiss_info_path
      dismiss_info_entity_document_path(document.entity, document)
    end
  end
end
