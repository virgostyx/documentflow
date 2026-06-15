# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity sidebar navigation", type: :system do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:user) { create(:user) }
  let(:contact) { create(:contact, entity: entity) }

  let!(:my_document) { create(:document, entity: entity, sender: contact, addressee: contact, subject: "My contract", created_by: user) }
  let!(:received_document) { create(:document, entity: entity, sender: contact, addressee: contact, subject: "Received contract") }

  before do
    create(:entity_user, :owner, entity: entity, user: user)
    create(:workflow_step, document: received_document, actor: user)

    sign_in_via_form(user)
    visit entity_documents_path(entity)
  end

  it "navigates between Documents, My documents, Received documents, Contacts and Settings" do
    expect(page).to have_content("My contract")
    expect(page).to have_content("Received contract")

    click_link "My documents"
    expect(page).to have_current_path(mine_entity_documents_path(entity))
    expect(page).to have_content("My contract")
    expect(page).not_to have_content("Received contract")

    click_link "Received documents"
    expect(page).to have_current_path(received_entity_documents_path(entity))
    expect(page).to have_content("Received contract")
    expect(page).not_to have_content("My contract")

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
