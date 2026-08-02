# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Shared document preview", type: :system, js: true do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :finalized, entity: entity, subject: "Supplier agreement") }
  let!(:shared_link) { create(:shared_link, document: document) }

  before do
    document.main_file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "main.pdf", content_type: "application/pdf")
  end

  it "lets an unauthenticated external recipient open and close the file preview" do
    visit shared_document_path(token: shared_link.token)

    click_link "Preview"

    within("dialog") do
      expect(page).to have_css("iframe")
      click_button "Close"
    end

    expect(page).not_to have_css("dialog[open]")
  end
end
