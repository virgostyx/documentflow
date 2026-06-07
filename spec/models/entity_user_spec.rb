# frozen_string_literal: true

require "rails_helper"

RSpec.describe EntityUser, type: :model do
  let(:entity) { create(:entity) }
  let(:user)   { create(:user) }

  subject(:entity_user) { build(:entity_user, entity: entity, user: user) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:invited_by).class_name("User").optional }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:invited_email) }

    describe "role inclusion" do
      %w[owner admin member guest].each do |role|
        it "accepts #{role}" do
          entity_user.role = role
          expect(entity_user).to be_valid
        end
      end

      it "rejects an unknown role" do
        entity_user.role = "superuser"
        expect(entity_user).not_to be_valid
        expect(entity_user.errors[:role]).to be_present
      end
    end

    describe "status inclusion" do
      %w[pending active suspended].each do |status|
        it "accepts #{status}" do
          entity_user.status = status
          expect(entity_user).to be_valid
        end
      end

      it "rejects an unknown status" do
        entity_user.status = "deleted"
        expect(entity_user).not_to be_valid
        expect(entity_user.errors[:status]).to be_present
      end
    end

    describe "user_id uniqueness scoped to entity_id" do
      it "rejects a duplicate user within the same entity" do
        create(:entity_user, entity: entity, user: user)
        duplicate = build(:entity_user, entity: entity, user: user)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end

      it "allows the same user in a different entity" do
        create(:entity_user, entity: entity, user: user)
        other_entity = create(:entity)
        different = build(:entity_user, entity: other_entity, user: user)
        expect(different).to be_valid
      end

      it "allows nil user_id (pending invitation)" do
        create(:entity_user, entity: entity, user: nil, invited_email: "a@example.com")
        second = build(:entity_user, entity: entity, user: nil, invited_email: "b@example.com")
        expect(second).to be_valid
      end
    end
  end

  # ── Callbacks ─────────────────────────────────────────────────────────────

  describe "before_validation :set_invited_at" do
    it "sets invited_at on create when blank" do
      eu = build(:entity_user, entity: entity, user: user, invited_at: nil)
      eu.valid?
      expect(eu.invited_at).not_to be_nil
    end
  end

  describe "before_create :generate_invitation_token" do
    it "generates an invitation_token on create" do
      eu = create(:entity_user, entity: entity, user: user)
      expect(eu.invitation_token).to be_present
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe "scopes" do
    let!(:active_member)   { create(:entity_user, entity: entity, role: "member", status: "active") }
    let!(:pending_admin)   { create(:entity_user, entity: entity, role: "admin", status: "pending") }
    let!(:suspended_owner) { create(:entity_user, :owner, :suspended, entity: entity) }
    let!(:guest_member)    { create(:entity_user, :guest, entity: entity) }

    describe ".active" do
      it "returns only active entity users" do
        expect(EntityUser.active).to include(active_member, guest_member)
        expect(EntityUser.active).not_to include(pending_admin, suspended_owner)
      end
    end

    describe ".pending" do
      it "returns only pending entity users" do
        expect(EntityUser.pending).to include(pending_admin)
        expect(EntityUser.pending).not_to include(active_member, suspended_owner)
      end
    end

    describe ".owners" do
      it "returns only owners" do
        expect(EntityUser.owners).to include(suspended_owner)
        expect(EntityUser.owners).not_to include(active_member, pending_admin, guest_member)
      end
    end

    describe ".admins" do
      it "returns only admins" do
        expect(EntityUser.admins).to include(pending_admin)
        expect(EntityUser.admins).not_to include(active_member, suspended_owner, guest_member)
      end
    end

    describe ".members" do
      it "returns only members" do
        expect(EntityUser.members).to include(active_member)
        expect(EntityUser.members).not_to include(pending_admin, suspended_owner, guest_member)
      end
    end

    describe ".guests" do
      it "returns only guests" do
        expect(EntityUser.guests).to include(guest_member)
        expect(EntityUser.guests).not_to include(active_member, pending_admin, suspended_owner)
      end
    end
  end

  # ── Instance methods ──────────────────────────────────────────────────────

  describe "#owner?" do
    it "returns true when role is owner" do
      expect(build(:entity_user, :owner).owner?).to be true
    end

    it "returns false otherwise" do
      expect(build(:entity_user, role: "member").owner?).to be false
    end
  end

  describe "#admin?" do
    it "returns true when role is admin" do
      expect(build(:entity_user, :admin).admin?).to be true
    end

    it "returns false otherwise" do
      expect(build(:entity_user, role: "member").admin?).to be false
    end
  end

  describe "#member?" do
    it "returns true when role is member" do
      expect(build(:entity_user, role: "member").member?).to be true
    end

    it "returns false otherwise" do
      expect(build(:entity_user, :owner).member?).to be false
    end
  end

  describe "#guest?" do
    it "returns true when role is guest" do
      expect(build(:entity_user, :guest).guest?).to be true
    end

    it "returns false otherwise" do
      expect(build(:entity_user, role: "member").guest?).to be false
    end
  end

  describe "#active?" do
    it "returns true when status is active" do
      expect(build(:entity_user, status: "active").active?).to be true
    end

    it "returns false otherwise" do
      expect(build(:entity_user, status: "pending").active?).to be false
    end
  end

  describe "#pending?" do
    it "returns true when status is pending" do
      expect(build(:entity_user, status: "pending").pending?).to be true
    end

    it "returns false otherwise" do
      expect(build(:entity_user, status: "active").pending?).to be false
    end
  end

  describe "#suspended?" do
    it "returns true when status is suspended" do
      expect(build(:entity_user, status: "suspended").suspended?).to be true
    end

    it "returns false otherwise" do
      expect(build(:entity_user, status: "active").suspended?).to be false
    end
  end

  describe "#accept_for!" do
    it "associates the accepting user, sets status to active, and records accepted_at" do
      accepting_user = create(:user)
      eu = create(:entity_user, entity: entity, user: nil,
                                invited_email: accepting_user.email, status: "pending")
      eu.accept_for!(accepting_user)
      expect(eu.reload.user).to eq(accepting_user)
      expect(eu.status).to eq("active")
      expect(eu.accepted_at).not_to be_nil
    end
  end
end
