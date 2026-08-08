# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Multi-recipient templated dispatch golden path", type: :system do
  include ActiveJob::TestHelper

  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let(:visa_actor) { create(:user) }
  let(:sign_actor) { create(:user) }
  let(:exp_actor) { create(:user) }

  # Deliberately not "Jean Dupont" - that's the :contact factory's own default
  # name, and this document's auto-created default sender would collide with it.
  # let! (not let): bidder_b/bidder_c must exist in the DB before the page is
  # first visited, since they're only referenced inside the example body below.
  let(:bidder_a) { create(:contact, entity: entity, first_name: "Ahmed", last_name: "Benali") }
  let!(:bidder_b) { create(:contact, entity: entity, first_name: "Marie", last_name: "Petit") }
  let!(:bidder_c) { create(:contact, entity: entity, first_name: "Paul", last_name: "Martin") }

  let(:document) do
    create(:document, entity: entity, created_by: owner, subject: "Tender - road works", addressee: bidder_a)
  end

  let!(:email_template) do
    create(:email_template, entity: entity, created_by: owner, name: "Bid call",
      body_template: "Dear {{recipient_name}}, please submit your bid for {{reference}} before {{deadline}}.")
  end

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = original_adapter
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

  it "sends a personalized, individually-attached email to every bulk-added recipient and records the dispatch status" do
    sign_in_via_form(owner)
    visit entity_document_path(entity, document)

    find("summary", text: "Add multiple recipients at once").click
    check bidder_b.display_name
    check bidder_c.display_name
    click_button "Add selected recipients"
    expect(page).to have_content("Recipients added to copy successfully")
    expect(document.cc_recipients.reload.map(&:party)).to contain_exactly(bidder_b, bidder_c)
    expect(document.reload.multi_recipient).to be true

    open_actions_menu
    click_link "Launch"
    expect(page).to have_content("Document launched successfully")

    open_actions_menu
    click_link "Approve"
    expect(page).to have_content("approved")

    sign_out_via_ui(owner)
    sign_in_via_form(visa_actor)
    visit entity_document_path(entity, document)
    open_actions_menu
    click_link "Approve"
    expect(page).to have_content("approved")

    sign_out_via_ui(visa_actor)
    sign_in_via_form(sign_actor)
    visit entity_document_path(entity, document)
    open_actions_menu
    click_link "Approve"
    expect(page).to have_content("Sign document")

    sign_step = document.reload.workflow_steps.find_by(role: "SIGN")
    token = SecureRandom.hex(32)
    Workflow::ApproveStepOrganizer.call(
      step: sign_step, current_user: sign_actor,
      step_up_token: token,
      step_up_tokens: { sign_step.id.to_s => { "token" => token, "expires_at" => 2.minutes.from_now.to_i } }
    )

    sign_out_via_ui(sign_actor)
    sign_in_via_form(exp_actor)
    visit entity_document_path(entity, document)
    open_actions_menu
    click_link "Approve"
    expect(page).to have_content("Approve and dispatch")

    select email_template.name, from: "email_template_id"
    click_button "Load template"

    fill_in "Reference", with: "TND-2026-042"
    fill_in "Deadline", with: "2026-09-01"
    click_button "Insert into message"
    expect(page).to have_field("dispatch_message", with: /Dear \{\{recipient_name\}\}, please submit your bid for TND-2026-042 before 2026-09-01\./)

    perform_enqueued_jobs do
      click_button "Approve"
    end

    expect(page).to have_content("Finalized")

    # Besides the 3 bidders, the document's creator also gets an internal
    # "document finalized" notification - only assert on the 3 bidder emails.
    deliveries = ActionMailer::Base.deliveries

    [ bidder_a, bidder_b, bidder_c ].each do |bidder|
      mail = deliveries.find { |m| m.to == [ bidder.email ] }
      expect(mail).to be_present
      expect(mail.text_part.body.encoded).to include(
        "Dear #{bidder.display_name}, please submit your bid for TND-2026-042 before 2026-09-01."
      )
    end

    dispatch_sent_logs = document.audit_logs.reload.where(action: "dispatch_sent")
    expect(dispatch_sent_logs.count).to eq(3)
    expect(dispatch_sent_logs.map { |log| log.change_data["recipient_email"] }).to contain_exactly(
      bidder_a.email, bidder_b.email, bidder_c.email
    )

    visit entity_document_path(entity, document)
    [ bidder_a, bidder_b, bidder_c ].each { |bidder| expect(page).to have_content(bidder.display_name) }
    expect(page).to have_content("Sent", count: 3)
  end
end
