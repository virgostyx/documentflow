# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::MainFileComponent, type: :component do
  let(:user) { create(:user) }
  let(:document) { create(:document, created_by: user) }

  subject { render_inline(described_class.new(document: document, current_user: user)) }

  context "when the document has no main document attached" do
    it "displays an empty message" do
      expect(subject).to have_text("No main document attached yet")
    end
  end

  context "when the document has a main document attached" do
    before do
      document.main_file.attach(
        io: StringIO.new("content"),
        filename: "contract.pdf",
        content_type: "application/pdf"
      )
    end

    it "displays the file name" do
      expect(subject).to have_text("contract.pdf")
    end

    it "links to download the file" do
      expect(subject).to have_link("Download", href: Rails.application.routes.url_helpers.rails_blob_path(document.main_file, disposition: "attachment", only_path: true))
    end

    it "displays a remove link" do
      expect(subject).to have_link("Remove")
    end
  end

  context "when the current user cannot update the document" do
    let(:document) { create(:document, :in_progress, created_by: user) }

    it "does not display upload or remove controls" do
      expect(subject).not_to have_button("Upload")
      expect(subject).not_to have_link("Remove")
    end
  end
end
