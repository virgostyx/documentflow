# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Approve and dispatch modal", type: :system, js: true do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let(:exp_actor) { create(:user) }

  let(:document) { create(:document, :in_progress, entity: entity, created_by: owner, subject: "Supplier agreement") }

  let!(:email_template) do
    create(:email_template, entity: entity, created_by: owner, name: "Standard notice",
      body_template: "Dear {{recipient_name}}, please find the document attached.")
  end

  before do
    document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf")

    create(:entity_user, :owner, entity: entity, user: owner)
    create(:entity_user, entity: entity, user: exp_actor)

    create(:workflow_step, :red,  :approved, document: document, order: 1, actor: owner)
    create(:workflow_step, :visa, :approved, document: document, order: 2, actor: owner)
    create(:workflow_step, :sign, :approved, document: document, order: 3, actor: owner)
    create(:workflow_step, :exp,  document: document, order: 4, actor: exp_actor)

    sign_in_via_form(exp_actor)
    expect(page).to have_current_path(entity_documents_path(entity))

    visit entity_document_path(entity, document)
    open_actions_menu
    click_link "Approve"
    expect(page).to have_content("Approve and dispatch")
  end

  it "closes when Cancel is clicked" do
    click_button "Cancel"

    expect(page).not_to have_content("Approve and dispatch")
  end

  it "stays inside the modal when loading an email template, and Cancel still closes it afterwards" do
    select email_template.name, from: "email_template_id"
    click_button "Load template"

    expect(page).to have_content("Approve and dispatch")
    expect(page).to have_current_path(entity_document_path(entity, document))

    click_button "Cancel"

    expect(page).not_to have_content("Approve and dispatch")
  end
end
