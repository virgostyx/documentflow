# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document template golden path", type: :system do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:member) { create(:user, email: "member@example.com") }
  let(:sender_user) { create(:user, email: "sender@example.com") }
  let(:supplier_contact) { create(:contact, entity: entity, first_name: "Supplier", last_name: "Co") }
  let(:circuit_template) { create(:circuit_template, entity: entity, name: "Simple approval") }

  before do
    eu = create(:entity_user, entity: entity, user: member, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department, primary: true)
    create(:entity_user, entity: entity, user: sender_user, role: "member", status: "active")
    supplier_contact
    create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
    create(:circuit_template_step, circuit_template: circuit_template, role: "SIGN", order: 2)
  end

  it "creates a template with tags, generates a document from it, and applies its circuit" do
    sign_in_via_form(member)

    visit new_entity_document_template_path(entity)
    fill_in "Name", with: "VAT exemption request"
    select circuit_template.name, from: "Circuit template"
    select sender_user.display_name, from: "Default sender"
    select supplier_contact.display_name, from: "Default addressee"
    fill_in "Subject template", with: "VAT exemption request - {{supplier}}"
    attach_file "document_template[source_file]", Rails.root.join("spec/fixtures/files/vat_exemption_template.docx")
    click_button "Create document template"

    expect(page).to have_content("Document template created")
    expect(page).to have_content("Detected fields")
    expect(page).to have_field("Label", with: "Supplier")
    expect(page).to have_field("Label", with: "Amount")
    expect(page).to have_field("Label", with: "Tpin")

    visit entity_document_templates_path(entity)
    expect(page).to have_content("VAT exemption request")
    click_link "Generate document"

    expect(page).to have_field("Document date")
    select department.name, from: "Department" if page.has_select?("Department")
    fill_in "field_values[supplier]", with: "Acme Corp"
    fill_in "field_values[amount]", with: "1200 EUR"
    fill_in "field_values[tpin]", with: "1234567890"
    click_button "Generate document"

    expect(page).to have_content("Document generated successfully")
    expect(page).to have_content("VAT exemption request - Acme Corp")

    document = entity.documents.last
    expect(document.subject).to eq("VAT exemption request - Acme Corp")
    expect(document.sender).to eq(sender_user)
    expect(document.addressee).to eq(supplier_contact)
    expect(document.main_file).to be_attached
    expect(document.main_file.content_type).to eq(DocumentTemplate::DOCX_CONTENT_TYPE)
    document.main_file.open do |file|
      xml = Zip::File.open(file.path) { |zip| zip.read("word/document.xml") }
      expect(xml).to include("Please exempt the purchase from Acme Corp amounting to 1200 EUR, TPIN 1234567890.")
    end
    expect(document.workflow_steps.reload.pluck(:role, :order)).to eq([ [ "RED", 1 ], [ "SIGN", 2 ] ])
  end
end
