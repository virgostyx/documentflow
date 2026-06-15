# frozen_string_literal: true

require "rails_helper"

RSpec.describe CcRecipient, type: :model do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, entity: entity) }

  subject(:cc_recipient) { build(:cc_recipient, document: document) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:document) }
    it { is_expected.to belong_to(:party) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "is valid with a contact from the same entity" do
      cc_recipient.party = create(:contact, entity: entity)
      expect(cc_recipient).to be_valid
    end

    it "is valid with an internal user of the entity" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user, status: "active")

      cc_recipient.party = user

      expect(cc_recipient).to be_valid
    end

    it "rejects a contact from another entity" do
      cc_recipient.party = create(:contact, entity: create(:entity))
      expect(cc_recipient).not_to be_valid
      expect(cc_recipient.errors[:party]).to be_present
    end

    it "rejects a user who is not a member of the entity" do
      cc_recipient.party = create(:user)
      expect(cc_recipient).not_to be_valid
      expect(cc_recipient.errors[:party]).to be_present
    end

    it "rejects a duplicate party on the same document" do
      contact = create(:contact, entity: entity)
      create(:cc_recipient, document: document, party: contact)

      duplicate = build(:cc_recipient, document: document, party: contact)

      expect(duplicate).not_to be_valid
    end

    it "allows the same party to be in copy on different documents" do
      contact = create(:contact, entity: entity)
      other_document = create(:document, entity: entity)
      create(:cc_recipient, document: other_document, party: contact)

      cc_recipient.party = contact

      expect(cc_recipient).to be_valid
    end
  end

  # ── #party_token ─────────────────────────────────────────────────────────

  describe "#party_token" do
    it "reads back as Type-id for a contact" do
      contact = create(:contact, entity: entity)
      cc_recipient.party = contact

      expect(cc_recipient.party_token).to eq("Contact-#{contact.id}")
    end

    it "assigns the polymorphic party from a token" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user, status: "active")

      cc_recipient.party_token = "User-#{user.id}"

      expect(cc_recipient.party).to eq(user)
      expect(cc_recipient.party_type).to eq("User")
    end
  end
end
