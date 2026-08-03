# frozen_string_literal: true

module Documents
  # A single row of the documents table. Deliberately self-contained (no
  # dependency on an ambient current_entity/current_user controller helper)
  # so it can be rendered identically from a real request (documents/_table)
  # or out-of-request from DocumentRowBroadcastJob.
  class RowComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @current_user = current_user
    end

    private

    attr_reader :document, :current_user

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
  end
end
