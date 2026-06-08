# frozen_string_literal: true

module Documents
  class DocumentCardComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def default
      document = preview_document(subject: "Supplier agreement (preview - draft)", status: "draft")
      render(Documents::DocumentCardComponent.new(document: document, current_user: document.created_by))
    end

    def in_progress
      document = preview_document(subject: "Supplier agreement (preview - in progress)", status: "in_progress")
      render(Documents::DocumentCardComponent.new(document: document, current_user: document.created_by))
    end

    def finalized
      document = preview_document(subject: "Supplier agreement (preview - finalized)", status: "finalized")
      render(Documents::DocumentCardComponent.new(document: document, current_user: document.created_by))
    end
  end
end
