# frozen_string_literal: true

module Documents
  class MetadataComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def default
      document = preview_document(subject: "Supplier agreement (preview - metadata)")
      render(Documents::MetadataComponent.new(document: document))
    end
  end
end
