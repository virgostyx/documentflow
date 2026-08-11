# frozen_string_literal: true

require "rails_helper"

RSpec.describe DistributionListMember, type: :model do
  let(:entity) { create(:entity) }
  let(:distribution_list) { create(:distribution_list) }

  subject(:member) { build(:distribution_list_member, distribution_list: distribution_list, position: 1) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:distribution_list) }
    it { is_expected.to belong_to(:party) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:position) }

    it "rejects a duplicate party in the same list" do
      contact = create(:contact, entity: entity)
      create(:distribution_list_member, distribution_list: distribution_list, party: contact, position: 1)

      duplicate = build(:distribution_list_member, distribution_list: distribution_list, party: contact, position: 2)

      expect(duplicate).not_to be_valid
    end

    it "allows the same party in a different list" do
      contact = create(:contact, entity: entity)
      other_list = create(:distribution_list)
      create(:distribution_list_member, distribution_list: other_list, party: contact, position: 1)

      member.party = contact

      expect(member).to be_valid
    end

    it "is valid with a contact from any entity (lists are not entity-scoped)" do
      member.party = create(:contact, entity: create(:entity))
      expect(member).to be_valid
    end

    it "is valid with a user who is not a member of any entity (lists are not entity-scoped)" do
      member.party = create(:user)
      expect(member).to be_valid
    end
  end

  # ── #party_token ─────────────────────────────────────────────────────────

  describe "#party_token" do
    it "reads back as Type-id for a contact" do
      contact = create(:contact, entity: entity)
      member.party = contact

      expect(member.party_token).to eq("Contact-#{contact.id}")
    end

    it "assigns the polymorphic party from a token" do
      user = create(:user)
      member.party_token = "User-#{user.id}"

      expect(member.party).to eq(user)
      expect(member.party_type).to eq("User")
    end
  end

  # ── .ordered ─────────────────────────────────────────────────────────────

  describe ".ordered" do
    it "returns members sorted by position" do
      third = create(:distribution_list_member, distribution_list: distribution_list, position: 3)
      first = create(:distribution_list_member, distribution_list: distribution_list, position: 1)
      second = create(:distribution_list_member, distribution_list: distribution_list, position: 2)

      expect(distribution_list.distribution_list_members.ordered).to eq([ first, second, third ])
    end
  end
end
