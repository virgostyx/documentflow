# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contact, type: :model do
  let(:entity) { create(:entity) }

  subject(:contact) { build(:contact, entity: entity) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to allow_value("jean.dupont@example.com").for(:email) }
    it { is_expected.not_to allow_value("not-an-email").for(:email) }

    describe "email uniqueness scoped to entity" do
      it "rejects a duplicate email within the same entity" do
        create(:contact, entity: entity, email: "dup@example.com")
        duplicate = build(:contact, entity: entity, email: "dup@example.com")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to be_present
      end

      it "allows the same email in a different entity" do
        create(:contact, entity: entity, email: "dup@example.com")
        other_entity = create(:entity)
        different = build(:contact, entity: other_entity, email: "dup@example.com")
        expect(different).to be_valid
      end
    end
  end

  # ── Methods ───────────────────────────────────────────────────────────────

  describe "#full_name" do
    it "concatenates first and last name" do
      contact.first_name = "Jean"
      contact.last_name = "Dupont"
      expect(contact.full_name).to eq("Jean Dupont")
    end
  end
end
