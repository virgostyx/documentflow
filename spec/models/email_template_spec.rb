# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailTemplate, type: :model do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }

  subject(:email_template) { build(:email_template, entity: entity, created_by: user, body_template: "No tags here") }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to belong_to(:department).optional }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to have_many(:email_template_fields).dependent(:destroy) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:body_template) }

    it "validates uniqueness of name scoped to entity" do
      create(:email_template, entity: entity, created_by: user, name: "Bid call")

      duplicate = build(:email_template, entity: entity, created_by: user, name: "Bid call")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same name in a different entity" do
      create(:email_template, entity: entity, created_by: user, name: "Bid call")

      other_entity = create(:entity)
      other_template = build(:email_template, entity: other_entity, created_by: user, name: "Bid call")
      expect(other_template).to be_valid
    end

    it "rejects a department belonging to a different entity" do
      other_department = create(:department, entity: create(:entity))
      email_template.department = other_department

      expect(email_template).not_to be_valid
      expect(email_template.errors[:department]).to be_present
    end

    it "accepts a department belonging to the same entity" do
      email_template.department = create(:department, entity: entity)

      expect(email_template).to be_valid
    end
  end

  # ── Tag synchronization ──────────────────────────────────────────────────

  describe "tag synchronization" do
    it "creates a field for each unique tag found in the body" do
      email_template.body_template = "Reference: {{reference}}. Deadline: {{deadline}}."
      email_template.save!

      expect(email_template.email_template_fields.pluck(:tag_name)).to contain_exactly("reference", "deadline")
    end

    it "defaults the label to a humanized version of the tag and the type to text" do
      email_template.body_template = "Reference: {{tender_reference}}"
      email_template.save!

      field = email_template.email_template_fields.find_by(tag_name: "tender_reference")
      expect(field.label).to eq("Tender reference")
      expect(field.field_type).to eq("text")
    end

    it "does not duplicate an existing field when re-saving with the same tags" do
      email_template.body_template = "Reference: {{reference}}"
      email_template.save!

      field = email_template.email_template_fields.find_by(tag_name: "reference")
      field.update!(label: "Custom label", field_type: "textarea")

      email_template.update!(body_template: "Reference again: {{reference}}")

      expect(email_template.email_template_fields.where(tag_name: "reference").count).to eq(1)
      expect(email_template.email_template_fields.find_by(tag_name: "reference").label).to eq("Custom label")
    end

    it "removes a field whose tag no longer appears in the body" do
      email_template.body_template = "{{reference}} and {{deadline}}"
      email_template.save!
      expect(email_template.email_template_fields.pluck(:tag_name)).to contain_exactly("reference", "deadline")

      email_template.update!(body_template: "{{reference}} only")

      expect(email_template.email_template_fields.reload.pluck(:tag_name)).to contain_exactly("reference")
    end
  end

  # ── Reserved tags ─────────────────────────────────────────────────────────

  describe "reserved tags" do
    it "does not create fields for the reserved {{date}} and {{recipient_name}} tags" do
      email_template.body_template = "Dear {{recipient_name}}, issued on {{date}}."
      email_template.save!

      expect(email_template.email_template_fields).to be_empty
    end

    it "only creates fields for the non-reserved tags when mixed with reserved ones" do
      email_template.body_template = "Dear {{recipient_name}}, issued on {{date}} for {{reference}}."
      email_template.save!

      expect(email_template.email_template_fields.pluck(:tag_name)).to contain_exactly("reference")
    end

    it "still reports reserved tags via #tags even though they have no field" do
      email_template.body_template = "Dear {{recipient_name}}, issued on {{date}}."
      email_template.save!

      expect(email_template.tags).to include("date", "recipient_name")
    end
  end
end
