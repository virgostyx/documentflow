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
      expect(subject).to have_button("Add annex")
    end
  end

  context "when the document has annexes attached" do
    before do
      document.annexes.attach(
        io: StringIO.new("content"),
        filename: "appendix.pdf",
        content_type: "application/pdf"
      )
    end

    it "lists the attached file names" do
      expect(subject).to have_text("appendix.pdf")
    end

    it "links to download each annex" do
      expect(subject).to have_link("Download", href: Rails.application.routes.url_helpers.rails_blob_path(document.annexes.first, disposition: "attachment", only_path: true))
    end

    it "displays a remove link for each annex" do
      expect(subject).to have_link("Remove")
    end
  end

  context "when the current user cannot update the document" do
    let(:document) { create(:document, :in_progress, created_by: user) }

    before do
      document.annexes.attach(
        io: StringIO.new("content"),
        filename: "appendix.pdf",
        content_type: "application/pdf"
      )
    end

    it "does not display the add or remove controls" do
      expect(subject).not_to have_button("Add annex")
      expect(subject).not_to have_link("Remove")
    end
  end
end
