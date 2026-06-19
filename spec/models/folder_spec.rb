# frozen_string_literal: true

require "rails_helper"

RSpec.describe Folder, type: :model do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }

  subject(:folder) { build(:folder, entity: entity, department: department) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to belong_to(:department) }
    it { is_expected.to belong_to(:parent).class_name("Folder").optional }
    it { is_expected.to have_many(:children).class_name("Folder").dependent(:restrict_with_error) }
    it { is_expected.to have_many(:documents).dependent(:restrict_with_error) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of name scoped to department and parent" do
      create(:folder, entity: entity, department: department, name: "Contracts")

      duplicate = build(:folder, entity: entity, department: department, name: "Contracts")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same name under a different parent" do
      root = create(:folder, entity: entity, department: department, name: "Contracts")
      create(:folder, entity: entity, department: department, parent: root, name: "Drafts")

      other_root = create(:folder, entity: entity, department: department, name: "Invoices")
      sibling = build(:folder, entity: entity, department: department, parent: other_root, name: "Drafts")

      expect(sibling).to be_valid
    end

    it "allows the same name in a different department" do
      create(:folder, entity: entity, department: department, name: "Contracts")

      other_department = create(:department, entity: entity)
      other = build(:folder, entity: entity, department: other_department, name: "Contracts")

      expect(other).to be_valid
    end

    it "is invalid when the entity does not match the department's entity" do
      other_entity = create(:entity)
      folder.entity = other_entity

      expect(folder).not_to be_valid
      expect(folder.errors[:entity]).to be_present
    end

    it "is invalid when the parent belongs to a different department" do
      other_department = create(:department, entity: entity)
      other_parent = create(:folder, entity: entity, department: other_department)
      folder.parent = other_parent

      expect(folder).not_to be_valid
      expect(folder.errors[:parent]).to be_present
    end

    it "is invalid when the parent is itself a subfolder (max 2 levels)" do
      root = create(:folder, entity: entity, department: department)
      sub = create(:folder, entity: entity, department: department, parent: root)
      folder.parent = sub

      expect(folder).not_to be_valid
      expect(folder.errors[:parent]).to be_present
    end

    it "is valid when the parent is a root folder" do
      root = create(:folder, entity: entity, department: department)
      folder.parent = root

      expect(folder).to be_valid
    end
  end

  # ── Destroy guards ────────────────────────────────────────────────────────

  describe "destroy" do
    it "is blocked when subfolders still reference it" do
      folder.save!
      create(:folder, entity: entity, department: department, parent: folder)

      expect(folder.destroy).to be false
      expect(folder.errors[:base]).to be_present
    end

    it "is blocked when documents still reference it" do
      folder.save!
      create(:document, entity: entity, department: department, folder: folder)

      expect(folder.destroy).to be false
      expect(folder.errors[:base]).to be_present
    end

    it "succeeds when empty" do
      folder.save!

      expect(folder.destroy).to be_truthy
    end
  end

  # ── Methods ───────────────────────────────────────────────────────────────

  describe "#root?" do
    it "is true for a folder with no parent" do
      expect(folder).to be_root
    end

    it "is false for a subfolder" do
      root = create(:folder, entity: entity, department: department)
      folder.parent = root

      expect(folder).not_to be_root
    end
  end
end
