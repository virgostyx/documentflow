# frozen_string_literal: true

require "rails_helper"

RSpec.describe EntityUserDepartment, type: :model do
  let(:entity) { create(:entity) }
  let(:entity_user) { create(:entity_user, entity: entity) }
  let(:department) { create(:department, entity: entity) }

  subject(:entity_user_department) { build(:entity_user_department, entity_user: entity_user, department: department) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity_user) }
    it { is_expected.to belong_to(:department) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "validates uniqueness of department scoped to entity_user" do
      create(:entity_user_department, entity_user: entity_user, department: department)

      duplicate = build(:entity_user_department, entity_user: entity_user, department: department)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:department_id]).to be_present
    end

    it "rejects a department that belongs to a different entity" do
      other_department = create(:department, entity: create(:entity))
      mismatched = build(:entity_user_department, entity_user: entity_user, department: other_department)

      expect(mismatched).not_to be_valid
      expect(mismatched.errors[:department]).to be_present
    end

    it "allows a single primary department per entity_user" do
      create(:entity_user_department, :primary, entity_user: entity_user, department: department)

      other_department = create(:department, entity: entity)
      second_primary = build(:entity_user_department, :primary, entity_user: entity_user, department: other_department)

      expect(second_primary).not_to be_valid
      expect(second_primary.errors[:primary]).to be_present
    end

    it "allows multiple non-primary departments for the same entity_user" do
      create(:entity_user_department, entity_user: entity_user, department: department)

      other_department = create(:department, entity: entity)
      second = build(:entity_user_department, entity_user: entity_user, department: other_department)

      expect(second).to be_valid
    end
  end
end
