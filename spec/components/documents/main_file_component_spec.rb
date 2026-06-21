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

  context "when the document is checked out by another user" do
    let(:other_user) { create(:user) }

    before do
      document.main_file.attach(io: StringIO.new("content"), filename: "contract.pdf", content_type: "application/pdf")
      document.update!(checked_out_by: other_user, checked_out_at: Time.current)
    end

    it "shows a checked-out badge with the other user's email" do
      expect(subject).to have_text("Checked out by #{other_user.email}")
    end

    it "hides the upload/replace and remove controls" do
      expect(subject).not_to have_button("Replace")
      expect(subject).not_to have_link("Remove")
    end

    it "does not show check-in or cancel-checkout controls" do
      expect(subject).not_to have_link("Check in")
      expect(subject).not_to have_link("Cancel checkout")
    end
  end

  context "when the document has a main file attached and is not checked out" do
    before { document.main_file.attach(io: StringIO.new("content"), filename: "contract.pdf", content_type: "application/pdf") }

    it "shows a check-out control" do
      expect(subject).to have_link("Check out")
    end

    it "wires the check-out control to open the file download in a new tab" do
      link = subject.css("a").find { |a| a.text.strip == "Check out" }

      expect(link["data-controller"]).to eq("checkout")
      expect(link["data-action"]).to include("click->checkout#openDownload")
      expect(link["data-checkout-download-url-value"]).to eq(
        Rails.application.routes.url_helpers.rails_blob_path(document.main_file, disposition: "attachment", only_path: true)
      )
    end
  end

  context "when the document has no main file attached" do
    it "does not show a check-out control" do
      expect(subject).not_to have_link("Check out")
    end
  end

  context "when checked out by the current user" do
    before do
      document.main_file.attach(io: StringIO.new("content"), filename: "contract.pdf", content_type: "application/pdf")
      document.update!(checked_out_by: user, checked_out_at: Time.current)
    end

    it "shows check-in and cancel-checkout controls" do
      expect(subject).to have_link("Check in")
      expect(subject).to have_link("Cancel checkout")
    end

    it "does not show a check-out control" do
      expect(subject).not_to have_link("Check out")
    end
  end
end
