# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Distribution list golden path", type: :system, js: true do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }

  let!(:colleague) { create(:user, first_name: "Alice", last_name: "Colleague") }
  let!(:colleague_membership) { create(:entity_user, entity: entity, user: colleague, status: "active") }
  let!(:external_contact) { create(:contact, entity: entity, first_name: "Bob", last_name: "Vendor") }

  before { sign_in_via_form(owner) }

  it "builds a distribution list through the UI and applies it to a document" do
    visit distribution_lists_path
    click_link "New distribution list"

    fill_in "Name", with: "Quarterly partners"

    picker = find('select[data-distribution-list-builder-target="partyPicker"]')
    picker.find(:option, external_contact.display_name).select_option
    click_on "+ Add member"

    picker.find(:option, colleague.display_name).select_option
    click_on "+ Add member"

    click_button "Create distribution list"

    expect(page).to have_content("Distribution list created successfully.")
    expect(page).to have_content("Quarterly partners")

    list = DistributionList.find_by(name: "Quarterly partners")
    expect(list.distribution_list_members.ordered.map(&:party)).to eq([ external_contact, colleague ])

    document = create(:document, entity: entity, created_by: owner)
    visit entity_document_path(entity, document)

    find("summary", text: "Apply a saved distribution list").click
    within("details", text: "Apply a saved distribution list") do
      all("select[name='distribution_list_id']")[0].select("Quarterly partners")
      click_button "Add all as CC"
    end

    expect(page).to have_content("Recipients added to copy successfully.")
    expect(document.cc_recipients.reload.map(&:party)).to contain_exactly(external_contact, colleague)

    other_document = create(:document, entity: entity, created_by: owner)
    visit entity_document_path(entity, other_document)

    find("summary", text: "Apply a saved distribution list").click
    within("details", text: "Apply a saved distribution list") do
      all("select[name='distribution_list_id']")[1].select("Quarterly partners")
      click_button "Apply as addressee + CC"
    end

    click_button "Confirm"

    expect(page).to have_content("Distribution list applied successfully.")
    other_document.reload
    expect(other_document.addressee).to eq(external_contact)
    expect(other_document.cc_recipients.map(&:party)).to contain_exactly(colleague)
  end
end
