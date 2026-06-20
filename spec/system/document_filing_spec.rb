# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document filing", type: :system, js: true do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:department) { create(:department, entity: entity, name: "Finance") }
  let(:owner) { create(:user) }
  let(:contact) { create(:contact, entity: entity) }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:document) { create(:document, entity: entity, department: department, sender: contact, addressee: contact, subject: "Supplier contract") }

  before do
    sign_in_via_form(owner)
    expect(page).to have_current_path(entity_documents_path(entity))
  end

  it "creates a folder and a subfolder through the modal, files a document into the subfolder via right-click, then unfiles it" do
    visit entity_folders_path(entity)

    click_link "Add folder"
    within("dialog") do
      fill_in "Name", with: "Contracts"
      click_button "Create folder"
    end

    expect(page).to have_content("Folder created successfully")
    expect(page).to have_content("Contracts")

    click_link "Add subfolder"
    within("dialog") do
      fill_in "Name", with: "Drafts"
      click_button "Create subfolder"
    end

    expect(page).to have_content("Folder created successfully")
    expect(page).to have_content("Drafts")

    visit entity_documents_path(entity)
    row = find("tr", text: "Supplier contract")
    row.right_click

    within(row) { click_button "File in Contracts / Drafts" }

    expect(page).to have_content("Document filed into Drafts")

    within("aside") { click_link "Drafts" }
    expect(page).to have_content("Supplier contract")

    within("aside") { click_link "Unfiled" }
    expect(page).not_to have_content("Supplier contract")

    visit entity_documents_path(entity)
    row = find("tr", text: "Supplier contract")
    row.right_click
    within(row) { click_button "Remove from folder" }

    expect(page).to have_content("Document removed from folder")

    within("aside") { click_link "Unfiled" }
    expect(page).to have_content("Supplier contract")
  end

  it "blocks deleting a folder that still contains a document, through the modal" do
    folder = create(:folder, entity: entity, department: department, name: "Contracts")
    document.update!(folder: folder)

    visit entity_folders_path(entity)
    click_link "Delete"

    within("dialog") do
      expect(page).to have_content("blocked while it still contains")
      click_button "Delete"
    end

    expect(page).to have_content("Cannot delete record")
    expect(Folder.exists?(folder.id)).to be true
  end
end
