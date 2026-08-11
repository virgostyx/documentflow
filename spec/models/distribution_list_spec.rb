# frozen_string_literal: true

require "rails_helper"

RSpec.describe DistributionList, type: :model do
  let(:user) { create(:user) }

  subject(:distribution_list) { build(:distribution_list, user: user) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:distribution_list_members).dependent(:destroy) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of name scoped to user" do
      create(:distribution_list, user: user, name: "Quarterly partners")

      duplicate = build(:distribution_list, user: user, name: "Quarterly partners")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same name for a different user" do
      create(:distribution_list, user: user, name: "Quarterly partners")

      other_user = create(:user)
      other_list = build(:distribution_list, user: other_user, name: "Quarterly partners")
      expect(other_list).to be_valid
    end
  end

  # ── Nested attributes ────────────────────────────────────────────────────

  describe "nested attributes for members" do
    it "builds and destroys members through distribution_list_members_attributes" do
      entity = create(:entity)
      contact = create(:contact, entity: entity)
      list = create(:distribution_list, user: user)
      member = create(:distribution_list_member, distribution_list: list, party: contact, position: 1)

      list.update!(distribution_list_members_attributes: [ { id: member.id, _destroy: true } ])

      expect(list.distribution_list_members.reload).to be_empty
    end
  end
end
