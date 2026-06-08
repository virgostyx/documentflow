# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document validation circuit golden path", type: :system do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let(:visa_actor) { create(:user) }
  let(:sign_actor) { create(:user) }
  let(:exp_actor) { create(:user) }

  let(:document) do
    create(:document, entity: entity, created_by: owner, subject: "Supplier agreement")
  end

  before do
    create(:entity_user, :owner, entity: entity, user: owner)
    create(:entity_user, entity: entity, user: visa_actor)
    create(:entity_user, entity: entity, user: sign_actor)
    create(:entity_user, entity: entity, user: exp_actor)

    create(:workflow_step, :red,  document: document, order: 1, actor: owner)
    create(:workflow_step, :visa, document: document, order: 2, actor: visa_actor)
    create(:workflow_step, :sign, document: document, order: 3, actor: sign_actor)
    create(:workflow_step, :exp,  document: document, order: 4, actor: exp_actor)
  end

  it "moves a document from draft through every validation step to finalized" do
    sign_in_via_form(owner)
    visit entity_document_path(entity, document)
    expect(page).to have_content("Draft")

    click_link "Launch"
    expect(page).to have_content("Document launched successfully")
    expect(page).to have_content("In Progress")
    within("[data-role='RED']") { expect(page).to have_content("Approved") }
    within("[data-role='VISA']") { expect(page).to have_content("Pending") }

    click_link "Sign out"
    sign_in_via_form(visa_actor)
    visit entity_document_path(entity, document)
    click_button "Approve"
    expect(page).to have_content("approved")
    within("[data-role='VISA']") { expect(page).to have_content("Approved") }
    within("[data-role='SIGN']") { expect(page).to have_content("Pending") }

    click_link "Sign out"
    sign_in_via_form(sign_actor)
    visit entity_document_path(entity, document)
    click_button "Approve"
    within("[data-role='SIGN']") { expect(page).to have_content("Approved") }
    within("[data-role='EXP']") { expect(page).to have_content("Pending") }

    click_link "Sign out"
    sign_in_via_form(exp_actor)
    visit entity_document_path(entity, document)
    click_button "Approve"

    expect(page).to have_content("Finalized")
    within("[data-role='EXP']") { expect(page).to have_content("Approved") }
  end
end
