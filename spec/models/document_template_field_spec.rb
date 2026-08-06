# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentTemplateField, type: :model do
  let(:document_template) do
    template = build(:document_template, subject_template: "No tags here")
    attach_docx(template, :source_file, docx_paragraph("No tags here either"))
    template.save!
    template
  end

  subject(:field) { build(:document_template_field, document_template: document_template) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:document_template) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:tag_name) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_inclusion_of(:field_type).in_array(DocumentTemplateField::FIELD_TYPES) }

    it "validates uniqueness of tag_name scoped to document_template" do
      create(:document_template_field, document_template: document_template, tag_name: "supplier")

      duplicate = build(:document_template_field, document_template: document_template, tag_name: "supplier")
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

    it "ignores blank entries and surrounding whitespace" do
      field.options_text = "Yes,  , No ,"
      expect(field.options).to eq(%w[Yes No])
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe "default scope order" do
    it "returns fields ordered by position" do
      field2 = create(:document_template_field, document_template: document_template, position: 2, tag_name: "b")
      field1 = create(:document_template_field, document_template: document_template, position: 1, tag_name: "a")

      expect(document_template.document_template_fields.to_a).to eq([ field1, field2 ])
    end
  end
end
