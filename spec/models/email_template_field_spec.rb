# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailTemplateField, type: :model do
  let(:email_template) { create(:email_template, body_template: "No tags here") }

  subject(:field) { build(:email_template_field, email_template: email_template) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:email_template) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:tag_name) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_inclusion_of(:field_type).in_array(EmailTemplateField::FIELD_TYPES) }

    it "validates uniqueness of tag_name scoped to email_template" do
      create(:email_template_field, email_template: email_template, tag_name: "reference")

      duplicate = build(:email_template_field, email_template: email_template, tag_name: "reference")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tag_name]).to be_present
    end

    it "requires at least one option when field_type is select" do
      field.field_type = "select"
      field.options = []

      expect(field).not_to be_valid
      expect(field.errors[:options]).to be_present
    end

    it "allows options to be blank for non-select field types" do
      field.field_type = "text"
      field.options = []

      expect(field).to be_valid
    end
  end

  # ── #options_text ─────────────────────────────────────────────────────────

  describe "#options_text" do
    it "joins options into a comma-separated string" do
      field.options = %w[Yes No Maybe]
      expect(field.options_text).to eq("Yes, No, Maybe")
    end

    it "parses a comma-separated string into the options array" do
      field.options_text = "Yes, No, Maybe"
      expect(field.options).to eq(%w[Yes No Maybe])
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe "default scope order" do
    it "returns fields ordered by position" do
      field2 = create(:email_template_field, email_template: email_template, position: 2, tag_name: "b")
      field1 = create(:email_template_field, email_template: email_template, position: 1, tag_name: "a")

      expect(email_template.email_template_fields.to_a).to eq([ field1, field2 ])
    end
  end
end
