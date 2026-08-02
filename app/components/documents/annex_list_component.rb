# frozen_string_literal: true

module Documents
  class AnnexListComponent < ViewComponent::Base
    def initialize(document:, current_user:, shared_link: nil)
      @document = document
      @shared_link = shared_link
      @policy = Pundit.policy!(current_user, document)
    end

    def annexes
      document.annexes
    end

    def show_actions?
      @policy.update?
    end

    def preview_url(annex)
      if shared_link
        Rails.application.routes.url_helpers.preview_shared_document_annex_path(shared_link.token, annex)
      else
        Rails.application.routes.url_helpers.preview_entity_document_annex_path(document.entity, document, annex)
      end
    end

    private

    attr_reader :document, :shared_link
  end
end
