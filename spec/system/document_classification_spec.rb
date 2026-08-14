# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document classification", type: :system, js: true do
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

  it "creates a root node and a child node through the modal, files a document into the child via right-click, then unfiles it" do
    document.update!(status: "finalized")

    visit entity_classification_nodes_path(entity)

    click_link "Add root node"
    within("dialog") do
      fill_in "Code (e.g. 1.2.3)", with: "1"
      fill_in "Name", with: "Contracts"
      click_button "Create node"
    end

    expect(page).to have_content("Filing node created successfully")
    expect(page).to have_content("Contracts")

    click_link "Add child"
    within("dialog") do
      fill_in "Code (e.g. 1.2.3)", with: "1.1"
      fill_in "Name", with: "Drafts"
      click_button "Create node"
    end

    expect(page).to have_content("Filing node created successfully")
    expect(page).to have_content("Drafts")

    visit entity_documents_path(entity)
    row = find("tr", text: "Supplier contract")
    row.right_click
    within(row) { click_link "File..." }

    within("dialog") do
      within("[data-classification-picker-target='row']", text: "Drafts") { click_button "File here" }
    end

    expect(page).to have_content("Document filed under 1.1")

    within("aside") { click_link "Drafts" }
    expect(page).to have_content("Supplier contract")

    within("aside") { click_link "Not filed" }
    expect(page).not_to have_content("Supplier contract")

    visit entity_documents_path(entity)
    row = find("tr", text: "Supplier contract")
    row.right_click
    within(row) { click_link "File..." }

    within("dialog") { click_button "Remove filing" }

    expect(page).to have_content("Document unfiled")

    within("aside") { click_link "Not filed" }
    expect(page).to have_content("Supplier contract")
  end

  it "filters the picker as the user types and keeps ancestors of a match visible" do
    document.update!(status: "finalized")
    root = create(:classification_node, entity: entity, code: "1", name: "Contracts")
    create(:classification_node, entity: entity, parent: root, code: "1.1", name: "Drafts")
    create(:classification_node, entity: entity, code: "2", name: "Invoices")

    visit entity_documents_path(entity)
    row = find("tr", text: "Supplier contract")
    row.right_click
    within(row) { click_link "File..." }

    within("dialog") do
      fill_in "Search by code or name...", with: "drafts"

      expect(page).to have_content("Drafts")
      expect(page).to have_content("Contracts")
      expect(page).not_to have_content("Invoices")
    end
  end

  it "shows and updates the Filing card on the document show page" do
    root = create(:classification_node, entity: entity, code: "1", name: "Contracts")
    create(:classification_node, entity: entity, parent: root, code: "1.1", name: "Drafts")

    visit entity_document_path(entity, document)
    expect(page).to have_content("Filing")
    expect(page).to have_content("Not filed yet.")

    click_link "Change filing"

    within("dialog") do
      within("[data-classification-picker-target='row']", text: "Drafts") { click_button "File here" }
    end

    expect(page).to have_content("Document filed under 1.1")
    expect(page).to have_content("1 › 1.1 — Drafts")
  end

  it "blocks deleting a node that still contains a document, through the modal" do
    node = create(:classification_node, entity: entity, code: "1", name: "Contracts")
    document.update!(classification_node: node)

    visit entity_classification_nodes_path(entity)
    click_link "Delete"

    within("dialog") do
      expect(page).to have_content("blocked while it still contains")
      click_button "Delete"
    end

    expect(page).to have_content("Cannot delete record")
    expect(ClassificationNode.exists?(node.id)).to be true
  end
end
