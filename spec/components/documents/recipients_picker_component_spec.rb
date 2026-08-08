# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::RecipientsPickerComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:colleague) { create(:user, first_name: "Alice", last_name: "Martin") }
  let!(:contact) { create(:contact, entity: entity, first_name: "Bob", last_name: "Client") }
  let!(:other_contact) { create(:contact, entity: entity, first_name: "Carla", last_name: "Vendor") }

  before { create(:entity_user, entity: entity, user: colleague, status: "active") }

  subject { render_inline(described_class.new(entity: entity)) }

  it "renders a checkbox for each internal user and external contact" do
    expect(subject).to have_field(type: "checkbox", with: "User-#{colleague.id}")
    expect(subject).to have_field(type: "checkbox", with: "Contact-#{contact.id}")
    expect(subject).to have_field(type: "checkbox", with: "Contact-#{other_contact.id}")
  end

  it "labels each checkbox with the party's display name" do
    expect(subject).to have_content(colleague.display_name)
    expect(subject).to have_content(contact.display_name)
  end

  it "uses party_tokens[] as the checkbox field name by default" do
    expect(subject).to have_css("input[type=checkbox][name='party_tokens[]']", minimum: 3)
  end

  context "with exclude_tokens" do
    subject { render_inline(described_class.new(entity: entity, exclude_tokens: [ "Contact-#{contact.id}" ])) }

    it "omits the excluded party" do
      expect(subject).not_to have_field(type: "checkbox", with: "Contact-#{contact.id}")
    end

    it "still includes the other parties" do
      expect(subject).to have_field(type: "checkbox", with: "User-#{colleague.id}")
      expect(subject).to have_field(type: "checkbox", with: "Contact-#{other_contact.id}")
    end
  end

  context "with a custom field name" do
    subject { render_inline(described_class.new(entity: entity, name: "bulk[tokens][]")) }

    it "uses the custom name for the checkboxes" do
      expect(subject).to have_css("input[type=checkbox][name='bulk[tokens][]']", minimum: 3)
    end
  end

  it "wires up the client-side filter controller" do
    expect(subject).to have_css("[data-controller='recipients-picker']")
    expect(subject).to have_css("input[data-recipients-picker-target='search'][data-action='input->recipients-picker#filter']")
    expect(subject).to have_css("[data-recipients-picker-target='empty'].hidden")
  end

  it "tags each row with its lowercased display name for matching" do
    expect(subject).to have_css("[data-recipients-picker-target='row'][data-searchable-text='#{colleague.display_name.downcase}']")
    expect(subject).to have_css("[data-recipients-picker-target='row'][data-searchable-text='#{contact.display_name.downcase}']")
  end
end
