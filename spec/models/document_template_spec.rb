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
    it { is_expected.to validate_presence_of(:body_template) }

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
    it "creates a field for each unique tag found in subject and body" do
      document_template.subject_template = "Request for {{supplier}}"
      document_template.body_template = "Amount: {{amount}}. Supplier: {{supplier}}."
      document_template.save!

      expect(document_template.document_template_fields.pluck(:tag_name)).to contain_exactly("supplier", "amount")
    end

    it "defaults the label to a humanized version of the tag and the type to text" do
      document_template.subject_template = "Request for {{supplier_name}}"
      document_template.body_template = "Body"
      document_template.save!

      field = document_template.document_template_fields.find_by(tag_name: "supplier_name")
      expect(field.label).to eq("Supplier name")
      expect(field.field_type).to eq("text")
    end

    it "does not duplicate an existing field when re-saving with the same tags" do
      document_template.subject_template = "Request for {{supplier}}"
      document_template.body_template = "Body without other tags"
      document_template.save!

      field = document_template.document_template_fields.find_by(tag_name: "supplier")
      field.update!(label: "Custom label", field_type: "textarea")

      document_template.update!(body_template: "Amount: {{supplier}} again")

      expect(document_template.document_template_fields.where(tag_name: "supplier").count).to eq(1)
      expect(document_template.document_template_fields.find_by(tag_name: "supplier").label).to eq("Custom label")
    end

    it "removes a field whose tag no longer appears in the text" do
      document_template.subject_template = "Request for {{supplier}} and {{amount}}"
      document_template.body_template = "Body without any tags"
      document_template.save!
      expect(document_template.document_template_fields.pluck(:tag_name)).to contain_exactly("supplier", "amount")

      document_template.update!(subject_template: "Request for {{supplier}}")

      expect(document_template.document_template_fields.reload.pluck(:tag_name)).to contain_exactly("supplier")
    end
  end

  # ── Nested attributes ────────────────────────────────────────────────────

  describe "nested attributes" do
    it "updates an existing field's label, type and required flag" do
      document_template.subject_template = "Request for {{supplier}}"
      document_template.body_template = "Body without other tags"
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
