# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document check-out / check-in golden path", type: :system, js: true do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let(:visa_actor) { create(:user) }
  let(:sign_actor) { create(:user) }
  let(:exp_actor) { create(:user) }

  let(:document) do
    create(:document, entity: entity, created_by: owner, subject: "Supplier agreement", status: "in_progress")
  end

  before do
    document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf")

    create(:entity_user, :owner, entity: entity, user: owner)
    create(:entity_user, entity: entity, user: visa_actor)
    create(:entity_user, entity: entity, user: sign_actor)
    create(:entity_user, entity: entity, user: exp_actor)

    create(:workflow_step, :red,  :approved, document: document, order: 1, actor: owner)
    create(:workflow_step, :visa, document: document, order: 2, actor: visa_actor)
    create(:workflow_step, :sign, document: document, order: 3, actor: sign_actor)
    create(:workflow_step, :exp,  document: document, order: 4, actor: exp_actor)
  end

  it "lets the VISA actor check out, replace the file with a new version, and check back in" do
    sign_in_via_form(visa_actor)
    expect(page).to have_current_path(entity_documents_path(entity))
    visit entity_document_path(entity, document)

    original_window = current_window
    window_opened_by { click_link "Check out" }
    switch_to_window(original_window)
    expect(page).to have_content("checked out successfully")
    expect(page).to have_content("Checked out by #{visa_actor.email}")

    click_link "Check in"
    within("dialog") do
      expect(page).to have_button("Check in")
      attach_file "document_file_version[file]", Rails.root.join("spec/fixtures/files/sample.pdf")
      fill_in "document_file_version[comment]", with: "Fixed the payment terms"
      click_button "Check in"
    end

    expect(page).to have_content("checked in successfully")
    expect(page).not_to have_content("Checked out by")
    expect(page).to have_content("Version 1")
    expect(page).to have_content("Fixed the payment terms")

    click_button "Approve"
    expect(page).to have_content("approved")
    within("[data-role='VISA']") { expect(page).to have_content("Approved") }
    within("[data-role='SIGN']") { expect(page).to have_content("Pending") }

    click_link "Sign out"
    expect(page).to have_content("Sign in")
    sign_in_via_form(sign_actor)
    expect(page).to have_current_path(entity_documents_path(entity))
    visit entity_document_path(entity, document)
    click_button "Approve"

    expect(page).to have_content("approved")
    within("[data-role='SIGN']") { expect(page).to have_content("Approved") }
  end

  it "lets the VISA actor cancel a checkout without creating a new version" do
    sign_in_via_form(visa_actor)
    expect(page).to have_current_path(entity_documents_path(entity))
    visit entity_document_path(entity, document)

    original_window = current_window
    window_opened_by { click_link "Check out" }
    switch_to_window(original_window)
    expect(page).to have_content("Checked out by #{visa_actor.email}")

    click_link "Cancel checkout"
    within("dialog") do
      expect(page).to have_button("Release checkout")
      click_button "Release checkout"
    end

    expect(page).to have_content("Checkout released successfully")
    expect(page).not_to have_content("Checked out by")
    expect(document.reload.document_file_versions.count).to eq(0)

    click_button "Approve"
    expect(page).to have_content("approved")
    within("[data-role='VISA']") { expect(page).to have_content("Approved") }
  end
end
