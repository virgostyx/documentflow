# frozen_string_literal: true

require "rails_helper"

RSpec.describe Document, type: :model do
  let(:entity) { create(:entity) }

  subject(:document) { build(:document, entity: entity) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to belong_to(:sender).class_name("Contact") }
    it { is_expected.to belong_to(:addressee).class_name("Contact") }
    it { is_expected.to have_many_attached(:files) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:subject) }
    it { is_expected.to validate_length_of(:subject).is_at_most(255) }
    it { is_expected.to validate_presence_of(:document_date) }
    it { is_expected.to validate_presence_of(:status) }

    describe "status inclusion" do
      %w[draft in_progress signed finalized cancelled].each do |status|
        it "accepts #{status}" do
          document.status = status
          expect(document).to be_valid
        end
      end

      it "rejects an unknown status" do
        document.status = "archived"
        expect(document).not_to be_valid
        expect(document.errors[:status]).to be_present
      end
    end

    describe "sender and addressee scoped to the document's entity" do
      it "rejects a sender from another entity" do
        document.sender = create(:contact, entity: create(:entity))
        expect(document).not_to be_valid
        expect(document.errors[:sender]).to be_present
      end

      it "rejects an addressee from another entity" do
        document.addressee = create(:contact, entity: create(:entity))
        expect(document).not_to be_valid
        expect(document.errors[:addressee]).to be_present
      end
    end
  end

  # ── Callbacks ─────────────────────────────────────────────────────────────

  describe "before_validation :generate_reference_number" do
    it "generates a reference number matching YYYY/#####" do
      document.save!
      expect(document.reference_number).to match(/\A\d{4}\/\d{5}\z/)
    end

    it "increments the sequence for the same entity and year" do
      first = create(:document, entity: entity)
      second = create(:document, entity: entity)
      expect(ReferenceNumber.parse(second.reference_number).sequence)
        .to eq(ReferenceNumber.parse(first.reference_number).sequence + 1)
    end

    it "resets the counter every year" do
      travel_to(Date.new(2025, 12, 31)) { create(:document, entity: entity) }
      travel_to(Date.new(2026, 1, 1)) do
        doc = create(:document, entity: entity)
        expect(doc.reference_number).to eq("2026/00001")
      end
    end

    it "does not regenerate an existing reference number" do
      document.reference_number = "2020/00099"
      document.valid?
      expect(document.reference_number).to eq("2020/00099")
    end
  end

  # ── State machine (AASM) ──────────────────────────────────────────────────

  describe "state machine" do
    it "starts in draft" do
      expect(build(:document)).to be_draft
    end

    describe "#launch" do
      it "transitions from draft to in_progress" do
        document.save!
        expect(document.launch!).to be true
        expect(document).to be_in_progress
      end

      it "cannot be launched from in_progress" do
        document = create(:document, :in_progress)
        expect(document.may_launch?).to be false
      end
    end

    describe "#sign" do
      it "transitions from in_progress to signed" do
        document = create(:document, :in_progress)
        expect(document.sign!).to be true
        expect(document).to be_signed
      end

      it "cannot be signed from draft" do
        document.save!
        expect(document.may_sign?).to be false
      end
    end

    describe "#finalize" do
      it "transitions from signed to finalized and freezes the document" do
        document = create(:document, :signed)
        expect(document.finalize!).to be true
        expect(document).to be_finalized
        expect(document.is_frozen).to be true
      end

      it "cannot be finalized from in_progress" do
        document = create(:document, :in_progress)
        expect(document.may_finalize?).to be false
      end
    end

    describe "#cancel" do
      %w[draft in_progress signed].each do |status|
        it "transitions from #{status} to cancelled" do
          document = create(:document, status: status)
          expect(document.cancel!).to be true
          expect(document).to be_cancelled
        end
      end

      it "cannot be cancelled once finalized" do
        document = create(:document, :finalized)
        expect(document.may_cancel?).to be false
      end
    end
  end

  # ── Methods ───────────────────────────────────────────────────────────────

  describe "#frozen?" do
    it "returns true once finalized" do
      document = create(:document, :finalized)
      expect(document.frozen?).to be true
    end

    it "returns false before finalization" do
      document.save!
      expect(document.frozen?).to be false
    end
  end
end
