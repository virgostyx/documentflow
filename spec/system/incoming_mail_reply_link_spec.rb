# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Linking an incoming mail reply to its original document", type: :system, js: true do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:department) { create(:department, entity: entity, name: "Finance") }
  let(:creator) { create(:user) }
  let(:lead) { create(:user) }
  let!(:external_party) { create(:contact, entity: entity, first_name: "Jane", last_name: "Doe") }
  let!(:original) do
    create(:document, :finalized, :expecting_response, entity: entity, department: department,
      created_by: creator, addressee: external_party, subject: "Request for tax documents")
  end

  before do
    [ creator, lead ].each do |member|
      eu = create(:entity_user, entity: entity, user: member, role: "member", status: "active")
      create(:entity_user_department, :primary, entity_user: eu, department: department)
    end
  end

  it "clears the original from Waiting once the reply is registered and linked at routing" do
    Capybara.using_session(:creator) do
      sign_in_via_form(creator)
      expect(page).to have_content(creator.email)

      visit waiting_entity_documents_path(entity)
      expect(page).to have_content("Request for tax documents")
    end

    Capybara.using_session(:lead) do
      sign_in_via_form(lead)
      expect(page).to have_content(lead.email)

      visit new_entity_incoming_mail_path(entity)
      fill_in "Subject", with: "Re: Request for tax documents"
      fill_in "Document date", with: Date.current
      select "Jane Doe", from: "Sender"
      select lead.display_name, from: "Assign to"
      click_button "Register mail"
      expect(page).to have_content("Incoming mail registered successfully")

      click_link "Route this mail"
      within("dialog") do
        select lead.display_name, from: "Assign for action"
        select "#{original.display_number} — Request for tax documents", from: "Replies to (optional)"
        click_button "Route mail"
      end
      expect(page).to have_content("Mail routed successfully")

      # The "Document chain" card lives on the outgoing document's own show
      # page (Documents::ThreadComponent, wired up in Tasks 4-5) rather than
      # on the incoming mail's page, which has no such section.
      visit entity_document_path(entity, original)
      expect(page).to have_content("Document chain")
      expect(page).to have_content("Re: Request for tax documents")

      reply = Document.find_by!(subject: "Re: Request for tax documents")
      click_link reply.display_number
      expect(page).to have_current_path(entity_incoming_mail_path(entity, reply))
    end

    Capybara.using_session(:creator) do
      # Still the same signed-in :creator session from the first block above
      # (Capybara.using_session reuses the session/cookies by name) — signing
      # in again here would hit Devise's require_no_authentication guard on
      # the sign-in form and redirect before the form even renders.
      visit waiting_entity_documents_path(entity)
      expect(page).not_to have_content("Request for tax documents")

      visit entity_document_path(entity, original)
      expect(page).to have_content("Document chain")
      expect(page).to have_content("Re: Request for tax documents")
    end
  end
end
