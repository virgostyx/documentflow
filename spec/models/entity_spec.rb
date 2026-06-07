# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entity, type: :model do
  subject(:entity) { create(:entity) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to have_many(:entity_users).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:entity_users) }
    it { is_expected.to have_many(:contacts).dependent(:destroy) }
    it { is_expected.to have_one_attached(:logo) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:status) }

    describe "status inclusion" do
      it "accepts active" do
        entity.status = "active"
        expect(entity).to be_valid
      end

      it "accepts suspended" do
        entity.status = "suspended"
        expect(entity).to be_valid
      end

      it "accepts cancelled" do
        entity.status = "cancelled"
        expect(entity).to be_valid
      end

      it "rejects an unknown status" do
        entity.status = "archived"
        expect(entity).not_to be_valid
        expect(entity.errors[:status]).to be_present
      end
    end
  end

  # ── Callbacks ─────────────────────────────────────────────────────────────

  describe "before_validation :generate_code" do
    context "when code is blank" do
      let(:entity) { build(:entity, code: nil) }

      it "generates a code matching ENT-XXXXXX" do
        entity.valid?
        expect(entity.code).to match(/\AENT-[A-Z0-9]{6}\z/)
      end
    end

    context "when code is present" do
      let(:entity) { build(:entity, code: "ENT-ABC123") }

      it "keeps the existing code" do
        entity.valid?
        expect(entity.code).to eq("ENT-ABC123")
      end
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe "scopes" do
    let!(:active_entity)    { create(:entity, status: "active") }
    let!(:suspended_entity) { create(:entity, :suspended) }
    let!(:cancelled_entity) { create(:entity, :cancelled) }

    describe ".active" do
      it "returns only active entities" do
        expect(Entity.active).to include(active_entity)
        expect(Entity.active).not_to include(suspended_entity, cancelled_entity)
      end
    end

    describe ".suspended" do
      it "returns only suspended entities" do
        expect(Entity.suspended).to include(suspended_entity)
        expect(Entity.suspended).not_to include(active_entity, cancelled_entity)
      end
    end

    describe ".cancelled" do
      it "returns only cancelled entities" do
        expect(Entity.cancelled).to include(cancelled_entity)
        expect(Entity.cancelled).not_to include(active_entity, suspended_entity)
      end
    end
  end

  # ── Instance methods ──────────────────────────────────────────────────────

  describe "#active?" do
    it "returns true when status is active" do
      entity.status = "active"
      expect(entity.active?).to be true
    end

    it "returns false otherwise" do
      entity.status = "suspended"
      expect(entity.active?).to be false
    end
  end

  describe "#suspended?" do
    it "returns true when status is suspended" do
      entity.status = "suspended"
      expect(entity.suspended?).to be true
    end

    it "returns false otherwise" do
      entity.status = "active"
      expect(entity.suspended?).to be false
    end
  end

  describe "#cancelled?" do
    it "returns true when status is cancelled" do
      entity.status = "cancelled"
      expect(entity.cancelled?).to be true
    end

    it "returns false otherwise" do
      entity.status = "active"
      expect(entity.cancelled?).to be false
    end
  end
end
