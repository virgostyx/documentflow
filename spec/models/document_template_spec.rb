# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentTemplate, type: :model do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }

  subject(:document_template) { build(:document_template, entity: entity, created_by: user) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to belong_to(:department).optional }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to belong_to(:circuit_template).optional }
    it { is_expected.to have_many(:document_template_fields).dependent(:destroy) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:subject_template) }

    it "requires a source_file" do
      document_template.source_file.detach

      expect(document_template).not_to be_valid
      expect(document_template.errors[:source_file]).to be_present
    end

    it "rejects a source_file that isn't a .docx" do
      document_template.source_file.attach(
        io: StringIO.new("not a docx"), filename: "template.txt", content_type: "text/plain"
      )

      expect(document_template).not_to be_valid
      expect(document_template.errors[:source_file]).to be_present
    end

    it "validates uniqueness of name scoped to entity" do
      create(:document_template, entity: entity, created_by: user, name: "VAT exemption")

      duplicate = build(:document_template, entity: entity, created_by: user, name: "VAT exemption")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same name in a different entity" do
      create(:document_template, entity: entity, created_by: user, name: "VAT exemption")

      other_entity = create(:entity)
      other_template = build(:document_template, entity: other_entity, created_by: user, name: "VAT exemption")
      expect(other_template).to be_valid
    end

    it "rejects a department belonging to a different entity" do
      other_department = create(:department, entity: create(:entity))
      document_template.department = other_department

      expect(document_template).not_to be_valid
      expect(document_template.errors[:department]).to be_present
    end

    it "accepts a department belonging to the same entity" do
      document_template.department = create(:department, entity: entity)

      expect(document_template).to be_valid
    end

    it "rejects a default_sender belonging to a different entity" do
      document_template.default_sender = create(:contact, entity: create(:entity))

      expect(document_template).not_to be_valid
      expect(document_template.errors[:default_sender]).to be_present
    end

    it "rejects a default_addressee belonging to a different entity" do
      document_template.default_addressee = create(:contact, entity: create(:entity))

      expect(document_template).not_to be_valid
      expect(document_template.errors[:default_addressee]).to be_present
    end

    it "allows default_sender and default_addressee to be blank" do
      expect(document_template).to be_valid
    end
  end

  # ── Tag synchronization ──────────────────────────────────────────────────

  describe "tag synchronization" do
    it "creates a field for each unique tag found in the subject and the uploaded docx body" do
      document_template.subject_template = "Request for {{supplier}}"
      attach_docx(document_template, :source_file, docx_paragraph("Amount: {{amount}}. Supplier: {{supplier}}."))
      document_template.save!

      expect(document_template.document_template_fields.pluck(:tag_name)).to contain_exactly("supplier", "amount")
    end

    it "defaults the label to a humanized version of the tag and the type to text" do
      document_template.subject_template = "Request for {{supplier_name}}"
      attach_docx(document_template, :source_file, docx_paragraph("Body"))
      document_template.save!

      field = document_template.document_template_fields.find_by(tag_name: "supplier_name")
      expect(field.label).to eq("Supplier name")
      expect(field.field_type).to eq("text")
    end

    it "does not duplicate an existing field when re-saving with the same tags" do
      document_template.subject_template = "Request for {{supplier}}"
      attach_docx(document_template, :source_file, docx_paragraph("Body without other tags"))
      document_template.save!

      field = document_template.document_template_fields.find_by(tag_name: "supplier")
      field.update!(label: "Custom label", field_type: "textarea")

      attach_docx(document_template, :source_file, docx_paragraph("Amount: {{supplier}} again"))
      document_template.save!

      expect(document_template.document_template_fields.where(tag_name: "supplier").count).to eq(1)
      expect(document_template.document_template_fields.find_by(tag_name: "supplier").label).to eq("Custom label")
    end

    it "removes a field whose tag no longer appears in the text" do
      document_template.subject_template = "Request for {{supplier}} and {{amount}}"
      attach_docx(document_template, :source_file, docx_paragraph("Body without any tags"))
      document_template.save!
      expect(document_template.document_template_fields.pluck(:tag_name)).to contain_exactly("supplier", "amount")

      document_template.update!(subject_template: "Request for {{supplier}}")

      expect(document_template.document_template_fields.reload.pluck(:tag_name)).to contain_exactly("supplier")
    end

    it "detects a tag from the docx even when split across multiple runs" do
      document_template.subject_template = "No tags here"
      attach_docx(document_template, :source_file, docx_paragraph("Dear {{sup", "plier}}, hello."))
      document_template.save!

      expect(document_template.document_template_fields.pluck(:tag_name)).to contain_exactly("supplier")
    end
  end

  # ── Reserved tags ─────────────────────────────────────────────────────────

  describe "reserved tags" do
    it "does not create a field for the reserved {{date}} tag" do
      document_template.subject_template = "Issued on {{date}}"
      attach_docx(document_template, :source_file, docx_paragraph("No other tags here"))
      document_template.save!

      expect(document_template.document_template_fields).to be_empty
    end

    it "only creates fields for the non-reserved tags when mixed with {{date}}" do
      document_template.subject_template = "Issued on {{date}} for {{supplier}}"
      attach_docx(document_template, :source_file, docx_paragraph("No other tags here"))
      document_template.save!

      expect(document_template.document_template_fields.pluck(:tag_name)).to contain_exactly("supplier")
    end

    it "removes a previously-existing field named after a now-reserved tag" do
      document_template.subject_template = "No tags here"
      attach_docx(document_template, :source_file, docx_paragraph("No other tags here"))
      document_template.save!
      document_template.document_template_fields.create!(tag_name: "date", label: "Date", field_type: "text", position: 1)

      document_template.update!(subject_template: "Issued on {{date}}")

      expect(document_template.document_template_fields.reload).to be_empty
    end

    it "still reports the reserved tag via #tags even though it has no field" do
      document_template.subject_template = "Issued on {{date}}"
      attach_docx(document_template, :source_file, docx_paragraph("No other tags here"))
      document_template.save!

      expect(document_template.tags).to include("date")
    end
  end

  # ── Nested attributes ────────────────────────────────────────────────────

  describe "nested attributes" do
    it "updates an existing field's label, type and required flag" do
      document_template.subject_template = "Request for {{supplier}}"
      attach_docx(document_template, :source_file, docx_paragraph("Body without other tags"))
      document_template.save!
      field = document_template.document_template_fields.find_by(tag_name: "supplier")

      document_template.update!(
        document_template_fields_attributes: [
          { id: field.id, label: "Supplier name", field_type: "textarea", required: false }
        ]
      )

      field.reload
      expect(field.label).to eq("Supplier name")
      expect(field.field_type).to eq("textarea")
      expect(field.required).to be false
    end
  end
end
