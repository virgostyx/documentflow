# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document validation circuit edge cases", type: :system do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }

  before { create(:entity_user, :owner, entity: entity, user: owner) }

  describe "rejecting a workflow step" do
    let(:visa_actor) { create(:user) }
    let(:document) { create(:document, :in_progress, entity: entity, created_by: owner) }

    before do
      create(:entity_user, entity: entity, user: visa_actor)
      create(:workflow_step, :red,  :approved, document: document, order: 1, actor: owner)
      create(:workflow_step, :visa, document: document, order: 2, actor: visa_actor)
      create(:workflow_step, :sign, document: document, order: 3, actor: create(:user))
      create(:workflow_step, :exp,  document: document, order: 4, actor: create(:user))
    end

    it "returns the document to the previous step when an actor rejects it" do
      sign_in_via_form(visa_actor)
      visit entity_document_path(entity, document)

      open_actions_menu
      click_link "Reject"

      fill_in "Reason", with: "Missing signature page"
      click_button "Reject"

      expect(page).to have_content("Step rejected successfully.")
      within("[data-role='VISA']") { expect(page).to have_content("Rejected") }
      within("[data-role='RED']") { expect(page).to have_content("Pending") }
    end
  end

  describe "reassigning a step whose actor was removed from the entity" do
    let(:visa_actor) { create(:user) }
    let(:new_colleague) { create(:user) }
    let(:document) { create(:document, :in_progress, entity: entity, created_by: owner) }

    before do
      create(:entity_user, entity: entity, user: visa_actor, status: "active")
      new_colleague_membership = create(:entity_user, entity: entity, user: new_colleague, status: "active")
      create(:workflow_step, :red,  :approved, document: document, order: 1, actor: owner)
      create(:workflow_step, :visa, document: document, order: 2, actor: visa_actor)
      create(:workflow_step, :sign, document: document, order: 3, actor: create(:user))
      create(:workflow_step, :exp,  document: document, order: 4, actor: create(:user))

      # The VISA actor leaves the entity: their membership is destroyed, so they
      # can no longer access it, but the workflow step still points at them.
      EntityUser.find_by(entity: entity, user: visa_actor).destroy
      new_colleague_membership
    end

    it "lets the owner reassign the stuck step, and the new actor can then approve it" do
      sign_in_via_form(owner)
      visit entity_document_path(entity, document)

      within("[data-role='VISA']") do
        select new_colleague.display_name, from: "actor_id"
        click_button "Reassign"
      end

      expect(page).to have_content("Step reassigned successfully.")
      within("[data-role='VISA']") { expect(page).to have_content(new_colleague.email) }

      sign_out_via_ui(owner)
      sign_in_via_form(new_colleague)
      visit entity_document_path(entity, document)

      open_actions_menu
      click_link "Approve"

      expect(page).to have_content("Step approved successfully.")
      within("[data-role='VISA']") { expect(page).to have_content("Approved") }
    end
  end

  describe "share links" do
    let(:document) { create(:document, :finalized, entity: entity, created_by: owner) }

    it "lets entity staff generate and revoke a public share link" do
      sign_in_via_form(owner)
      visit entity_document_path(entity, document)

      expect(page).to have_content("This document has not been shared yet.")

      click_link "Generate share link"
      expect(page).to have_content("Share link created successfully.")
      expect(page).not_to have_content("This document has not been shared yet.")
      expect(page).to have_content("Revoke")

      click_link "Revoke"
      expect(page).to have_content("Share link revoked successfully.")
      expect(page).to have_content("This document has not been shared yet.")
    end
  end

  describe "searching documents" do
    let!(:matching_document) { create(:document, :finalized, entity: entity, created_by: owner, subject: "Annual budget review") }
    let!(:other_document) { create(:document, :finalized, entity: entity, created_by: owner, subject: "Office lease renewal") }

    it "filters the document list by the search query" do
      sign_in_via_form(owner)
      visit entity_documents_path(entity)

      expect(page).to have_content(matching_document.subject)
      expect(page).to have_content(other_document.subject)

      visit search_entity_documents_path(entity, q: "budget")

      expect(page).to have_content(matching_document.subject)
      expect(page).not_to have_content(other_document.subject)
    end
  end
end
