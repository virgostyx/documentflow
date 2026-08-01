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
    document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf")

    create(:entity_user, :owner, entity: entity, user: owner)
    create(:entity_user, entity: entity, user: visa_actor)
    create(:entity_user, entity: entity, user: sign_actor)
    create(:entity_user, entity: entity, user: exp_actor)

    create(:workflow_step, :red,  document: document, order: 1, actor: owner)
    create(:workflow_step, :visa, document: document, order: 2, actor: visa_actor)
    create(:workflow_step, :sign, document: document, order: 3, actor: sign_actor)
    create(:workflow_step, :exp,  document: document, order: 4, actor: exp_actor)

    create(:signature_image, user: sign_actor)
  end

  it "moves a document from draft through every validation step to finalized" do
    sign_in_via_form(owner)
    visit entity_document_path(entity, document)
    expect(page).to have_content("Draft")

    open_actions_menu
    click_link "Launch"
    expect(page).to have_content("Document launched successfully")
    expect(page).to have_content("In Progress")
    within("[data-role='RED']") { expect(page).to have_content("Pending") }

    open_actions_menu
    click_link "Approve"
    expect(page).to have_content("approved")
    within("[data-role='RED']") { expect(page).to have_content("Approved") }
    within("[data-role='VISA']") { expect(page).to have_content("Pending") }

    sign_out_via_ui(owner)
    sign_in_via_form(visa_actor)
    visit entity_document_path(entity, document)
    open_actions_menu
    click_link "Approve"
    expect(page).to have_content("approved")
    within("[data-role='VISA']") { expect(page).to have_content("Approved") }
    within("[data-role='SIGN']") { expect(page).to have_content("Pending") }

    sign_out_via_ui(visa_actor)
    sign_in_via_form(sign_actor)
    visit entity_document_path(entity, document)
    open_actions_menu
    click_link "Approve"

    # SIGN approval requires a real WebAuthn step-up ceremony, which isn't
    # driven through a browser here (see spec/requests/workflow_steps/step_up_challenges_spec.rb
    # for full ceremony coverage) - this only confirms the confirmation modal
    # opens, then completes the approval directly to continue the golden path.
    expect(page).to have_content("Sign document")
    expect(page).to have_button("Verify & Sign")

    # document's in-memory attributes are stale (last touched at creation, via
    # this test's own Ruby object) - the RED/VISA approvals above happened
    # through separate objects in the browser-driven requests. Reload before
    # traversing the association, or WorkflowStep#document (auto inverse_of)
    # hands back this same stale object instead of querying the DB.
    sign_step = document.reload.workflow_steps.find_by(role: "SIGN")
    token = SecureRandom.hex(32)
    Workflow::ApproveStepOrganizer.call(
      step: sign_step, current_user: sign_actor,
      step_up_token: token,
      step_up_tokens: { sign_step.id.to_s => { "token" => token, "expires_at" => 2.minutes.from_now.to_i } }
    )

    visit entity_document_path(entity, document)
    within("[data-role='SIGN']") { expect(page).to have_content("Approved") }
    within("[data-role='EXP']") { expect(page).to have_content("Pending") }

    sign_out_via_ui(sign_actor)
    sign_in_via_form(exp_actor)
    visit entity_document_path(entity, document)
    open_actions_menu
    click_link "Approve"

    expect(page).to have_content("Finalized")
    within("[data-role='EXP']") { expect(page).to have_content("Approved") }
  end
end
