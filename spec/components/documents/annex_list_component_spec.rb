# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::AnnexListComponent, type: :component do
  let(:user) { create(:user) }
  let(:document) { create(:document, created_by: user) }

  subject { render_inline(described_class.new(document: document, current_user: user)) }

  context "when the document has no annexes attached" do
    it "displays an empty message" do
      expect(subject).to have_text("No annexes attached")
    end

    it "displays the add annex form" do
      expect(subject).to have_css("input[type=file]")
    end
  end

  context "when the document has annexes attached" do
    before do
      document.annexes.create!(
        file: { io: StringIO.new("content"), filename: "appendix.pdf", content_type: "application/pdf" }
      )
    end

    it "lists the attached file names" do
      expect(subject).to have_text("appendix.pdf")
    end

    it "links to download each annex" do
      expect(subject).to have_link("Download", href: Rails.application.routes.url_helpers.rails_blob_path(document.annexes.first.file, disposition: "attachment", only_path: true))
    end

    it "links to preview each annex" do
      annex = document.annexes.first
      expect(subject).to have_css("a[href='#{Rails.application.routes.url_helpers.preview_entity_document_annex_path(document.entity, document, annex)}']")
    end

    it "scopes the keep-original-format checkbox under annex[] so the controller's params.require(:annex) succeeds" do
      expect(subject).to have_css("input[name='annex[skip_pdf_conversion]']")
    end

    it "displays a remove link for each annex" do
      expect(subject).to have_link("Remove")
    end
  end

  context "when the current user cannot update the document" do
    let(:document) { create(:document, :in_progress, created_by: user) }

    before do
      document.annexes.create!(
        file: { io: StringIO.new("content"), filename: "appendix.pdf", content_type: "application/pdf" }
      )
    end

    it "does not display the add or remove controls" do
      expect(subject).not_to have_css("input[type=file]")
      expect(subject).not_to have_link("Remove")
    end
  end

  context "when rendered for a shared link (no authenticated user)" do
    let(:shared_link) { create(:shared_link, document: document) }

    subject { render_inline(described_class.new(document: document, current_user: nil, shared_link: shared_link)) }

    before do
      document.annexes.create!(
        file: { io: StringIO.new("content"), filename: "appendix.pdf", content_type: "application/pdf" }
      )
    end

    it "links to the public, token-based preview route instead of the authenticated one" do
      annex = document.annexes.first
      expect(subject).to have_css("a[href='#{Rails.application.routes.url_helpers.preview_shared_document_annex_path(shared_link.token, annex)}']")
    end

    it "still links to download each annex" do
      expect(subject).to have_link("Download", href: Rails.application.routes.url_helpers.rails_blob_path(document.annexes.first.file, disposition: "attachment", only_path: true))
    end

    it "does not display a remove link" do
      expect(subject).not_to have_link("Remove")
    end
  end
end
