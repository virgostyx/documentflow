# frozen_string_literal: true

module Documents
  class FileListComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def default
      document = preview_document(subject: "Supplier agreement (preview - files)")
      render(Documents::FileListComponent.new(document: document))
    end
  end
end
