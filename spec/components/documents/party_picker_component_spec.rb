# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::PartyPickerComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, entity: entity) }
  let(:colleague) { create(:user, first_name: "Alice", last_name: "Martin") }
  let(:form) { FloatingLabelsRails::FormBuilder.new(:document, document, vc_test_controller.view_context, {}) }

  let!(:contact) { create(:contact, entity: entity, first_name: "Bob", last_name: "Client") }

  before do
    create(:entity_user, entity: entity, user: colleague, status: "active")
  end

  subject do
    render_inline(described_class.new(
      form: form, attribute: :sender_token, entity: entity,
      label: "Sender", required: true, include_blank: "Select a sender..."
    ))
  end

  it "renders the grouped select with internal users and external contacts" do
    expect(subject).to have_select("document_sender_token", with_options: [ colleague.display_name, contact.display_name ])
  end

  it "renders a button to reveal the quick contact form" do
    expect(subject).to have_button("+ New contact")
  end

  it "renders a hidden quick contact form scoped to this picker" do
    expect(subject).to have_css("#document_sender_token_new_contact.hidden")
    expect(subject).to have_field("First name")
    expect(subject).to have_field("Email")
  end

  context "when show_new_contact is false" do
    subject do
      render_inline(described_class.new(
        form: form, attribute: :sender_token, entity: entity,
        label: "Sender", required: true, include_blank: "Select a sender...",
        show_new_contact: false
      ))
    end

    it "does not render a button to reveal the quick contact form" do
      expect(subject).not_to have_button("+ New contact")
    end

    it "does not render the quick contact form" do
      expect(subject).not_to have_css("#document_sender_token_new_contact")
    end
  end

  context "with additional_picker_ids" do
    subject do
      render_inline(described_class.new(
        form: form, attribute: :addressee_token, entity: entity,
        label: "Addressee", required: true, include_blank: "Select an addressee...",
        additional_picker_ids: [ "document_sender_token" ]
      ))
    end

    it "exposes the additional picker ids to the party-picker controller" do
      expect(subject).to have_css(%(div[data-party-picker-additional-picker-ids-value='["document_sender_token"]']))
    end
  end
end
