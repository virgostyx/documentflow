# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document template field options visibility", type: :system, js: true do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user, email: "owner@example.com") }
  let(:document_template) { create(:document_template, entity: entity) }

  let(:field) { document_template.document_template_fields.first }

  before do
    create(:entity_user, entity: entity, user: owner, role: "owner", status: "active")
    field.update!(field_type: "text")
  end

  it "only shows the Options field once the Select type is chosen" do
    sign_in_via_form(owner)

    visit edit_entity_document_template_path(entity, document_template)

    within("##{ActionView::RecordIdentifier.dom_id(field)}") do
      options_field = find_field("Options (comma-separated)", visible: :all)
      expect(options_field).not_to be_visible

      select "Select", from: "Type"
      expect(options_field).to be_visible

      select "Text", from: "Type"
      expect(options_field).not_to be_visible
    end
  end
end
