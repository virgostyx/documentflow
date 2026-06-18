# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity sidebar navigation", type: :system do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:user) { create(:user) }
  let(:contact) { create(:contact, entity: entity) }

  let!(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }
  let!(:my_document) { create(:document, entity: entity, sender: contact, addressee: contact, subject: "My contract", created_by: user) }
  let!(:received_document) { create(:document, entity: entity, sender: contact, addressee: user, subject: "Received contract") }
  let!(:todo_document) { create(:document, :expecting_response, entity: entity, sender: contact, addressee: user, subject: "Document needing my reply") }
  let!(:waiting_document) { create(:document, :expecting_response, entity: entity, sender: contact, addressee: contact, subject: "Document awaiting a reply", created_by: user) }

  before do
    sign_in_via_form(user)
    visit entity_documents_path(entity)
  end

  it "navigates between Documents, My Inbox, My Outbox, ToDo, Waiting, Info, Contacts and Settings" do
    expect(page).to have_content("My contract")
    expect(page).to have_content("Received contract")

    click_link "My Outbox"
    expect(page).to have_current_path(mine_entity_documents_path(entity))
    expect(page).to have_content("My contract")
    expect(page).not_to have_content("Received contract")

    click_link "My Inbox"
    expect(page).to have_current_path(received_entity_documents_path(entity))
    expect(page).to have_content("Received contract")
    expect(page).not_to have_content("My contract")

    click_link "ToDo"
    expect(page).to have_current_path(todo_entity_documents_path(entity))
    expect(page).to have_content("Document needing my reply")
    expect(page).not_to have_content("Received contract")
    expect(page).not_to have_content("My contract")

    click_link "Waiting"
    expect(page).to have_current_path(waiting_entity_documents_path(entity))
    expect(page).to have_content("Document awaiting a reply")
    expect(page).not_to have_content("Document needing my reply")

    click_link "Info"
    expect(page).to have_current_path(info_entity_documents_path(entity))
    expect(page).to have_content("My contract")
    expect(page).to have_content("Received contract")
    expect(page).not_to have_content("Document needing my reply")
    expect(page).not_to have_content("Document awaiting a reply")

    within("aside") { click_link(href: entity_documents_path(entity)) }
    expect(page).to have_current_path(entity_documents_path(entity))
    expect(page).to have_content("My contract")
    expect(page).to have_content("Received contract")

    within("aside") { click_link(href: entity_contacts_path(entity)) }
    expect(page).to have_current_path(entity_contacts_path(entity))
    expect(page).to have_content("Contacts")

    click_link "Settings"
    expect(page).to have_current_path(entity_settings_path(entity))
    expect(page).to have_content(entity.name)
    expect(page).to have_content(user.email)
  end
end
