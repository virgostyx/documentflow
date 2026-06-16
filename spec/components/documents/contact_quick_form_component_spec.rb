# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::ContactQuickFormComponent, type: :component do
  let(:entity) { create(:entity) }

  context "when closed (default)" do
    subject { render_inline(described_class.new(entity: entity, picker_id: "document_sender_token")) }

    it "renders hidden" do
      expect(subject).to have_css("#document_sender_token_new_contact.hidden")
    end

    it "renders empty input fields with floating labels" do
      expect(subject).to have_field("First name", with: "")
      expect(subject).to have_field("Email", with: "")
    end

    it "renders a create contact button" do
      expect(subject).to have_button("Create contact")
    end
  end

  context "when open with a contact that failed validation" do
    let(:contact) { entity.contacts.new(first_name: "Bob", email: "not-an-email").tap(&:validate) }

    subject { render_inline(described_class.new(entity: entity, picker_id: "document_sender_token", contact: contact, open: true)) }

    it "is visible" do
      expect(subject).not_to have_css(".hidden")
    end

    it "displays validation errors" do
      expect(subject).to have_text("Last name")
    end

    it "preserves entered values" do
      expect(subject).to have_field("First name", with: "Bob")
    end

    it "highlights the invalid field" do
      expect(subject).to have_css("label[for='document_sender_token_last_name'].text-red-600")
    end
  end
end
