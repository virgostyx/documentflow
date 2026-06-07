# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::FileListComponent, type: :component do
  let(:document) { create(:document) }

  subject { render_inline(described_class.new(document: document)) }

  context "when the document has no files attached" do
    it "displays an empty message" do
      expect(subject).to have_text("No files attached")
    end
  end

  context "when the document has files attached" do
    before do
      document.files.attach(
        io: StringIO.new("content"),
        filename: "contract.pdf",
        content_type: "application/pdf"
      )
    end

    it "lists the attached file names" do
      expect(subject).to have_text("contract.pdf")
    end

    it "links to download each file" do
      expect(subject).to have_link("Download", href: Rails.application.routes.url_helpers.rails_blob_path(document.files.first, disposition: "attachment", only_path: true))
    end
  end
end
