# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bulk CC recipients picker filter", type: :system, js: true do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }

  let!(:bob) { create(:contact, entity: entity, first_name: "Bob", last_name: "Client") }
  let!(:carla) { create(:contact, entity: entity, first_name: "Carla", last_name: "Vendor") }
  let!(:document) { create(:document, entity: entity, created_by: owner) }

  before do
    sign_in_via_form(owner)
    visit entity_document_path(entity, document)
    find("summary", text: "Add multiple recipients at once").click
  end

  it "filters recipients as the user types and shows a message when nothing matches" do
    picker = find("[data-controller='recipients-picker']")

    fill_in "Search by name...", with: "bob"
    expect(picker).to have_content(bob.display_name)
    expect(picker).not_to have_content(carla.display_name)

    fill_in "Search by name...", with: ""
    expect(picker).to have_content(carla.display_name)

    fill_in "Search by name...", with: "nobody-matches-this"
    expect(picker).to have_content("No matching recipient found.")
    expect(picker).not_to have_content(bob.display_name)
  end
end
