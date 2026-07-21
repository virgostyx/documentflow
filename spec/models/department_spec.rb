# frozen_string_literal: true

require "rails_helper"

RSpec.describe Department, type: :model do
  let(:entity) { create(:entity) }

  subject(:department) { build(:department, entity: entity) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to have_many(:entity_user_departments).dependent(:destroy) }
    it { is_expected.to have_many(:entity_users).through(:entity_user_departments) }
    it { is_expected.to have_many(:documents).dependent(:restrict_with_error) }
    it { is_expected.to have_one_attached(:logo) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of name scoped to entity" do
      create(:department, entity: entity, name: "Finance")

      duplicate = build(:department, entity: entity, name: "Finance")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same name in a different entity" do
      create(:department, entity: entity, name: "Finance")

      other_entity = create(:entity)
      other_department = build(:department, entity: other_entity, name: "Finance")
      expect(other_department).to be_valid
    end

    it { is_expected.to validate_presence_of(:prefix) }
    it { is_expected.to validate_length_of(:prefix).is_at_most(8) }

    it "validates uniqueness of prefix scoped to entity" do
      create(:department, entity: entity, prefix: "FIN")

      duplicate = build(:department, entity: entity, prefix: "FIN")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:prefix]).to be_present
    end

    it "allows the same prefix in a different entity" do
      create(:department, entity: entity, prefix: "FIN")

      other_entity = create(:entity)
      other_department = build(:department, entity: other_entity, prefix: "FIN")
      expect(other_department).to be_valid
    end

    it "normalizes the prefix to uppercase" do
      department.prefix = "fin"
      department.valid?
      expect(department.prefix).to eq("FIN")
    end

    it "rejects a prefix with punctuation" do
      department.prefix = "FI-N"
      expect(department).not_to be_valid
      expect(department.errors[:prefix]).to be_present
    end

    describe "logo content type" do
      it "accepts a PNG logo" do
        department.logo.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/logo.png")),
          filename: "logo.png",
          content_type: "image/png"
        )

        expect(department).to be_valid
      end

      it "rejects a non-image logo" do
        department.logo.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/sample.pdf")),
          filename: "sample.pdf",
          content_type: "application/pdf"
        )

        expect(department).not_to be_valid
        expect(department.errors[:logo]).to be_present
      end
    end

    describe "logo size" do
      it "rejects a logo larger than the configured max size" do
        department.logo.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/logo.png")),
          filename: "logo.png",
          content_type: "image/png"
        )
        allow(department.logo.blob).to receive(:byte_size).and_return(Department::LOGO_MAX_SIZE + 1)

        expect(department).not_to be_valid
        expect(department.errors[:logo]).to be_present
      end
    end
  end

  # ── Destroy guard ─────────────────────────────────────────────────────────

  describe "destroy" do
    it "is blocked when documents still reference it" do
      department.save!
      create(:document, entity: entity, department: department)

      expect(department.destroy).to be false
      expect(department.errors[:base]).to be_present
    end

    it "succeeds when no documents reference it" do
      department.save!

      expect(department.destroy).to be_truthy
    end
  end

  # ── Scopes / methods ──────────────────────────────────────────────────────

  describe "#default?" do
    it "is true for the default department" do
      department.is_default = true
      expect(department).to be_default
    end

    it "is false otherwise" do
      department.is_default = false
      expect(department).not_to be_default
    end
  end

  describe ".default" do
    it "returns only default departments" do
      default_department = create(:department, :default, entity: entity)
      create(:department, entity: entity)

      expect(Department.default).to contain_exactly(default_department)
    end
  end
end
