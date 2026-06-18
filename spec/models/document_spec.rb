# frozen_string_literal: true

require "rails_helper"

RSpec.describe Document, type: :model do
  let(:entity) { create(:entity) }

  subject(:document) { build(:document, entity: entity) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to belong_to(:department) }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to belong_to(:sender) }
    it { is_expected.to belong_to(:addressee) }
    it { is_expected.to have_one_attached(:main_file) }
    it { is_expected.to have_many_attached(:annexes) }
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

      it "accepts a sender who is an internal user of the entity" do
        user = create(:user)
        create(:entity_user, entity: entity, user: user, status: "active")

        document.sender = user

        expect(document).to be_valid
      end

      it "rejects a sender who is a user not belonging to the entity" do
        document.sender = create(:user)

        expect(document).not_to be_valid
        expect(document.errors[:sender]).to be_present
      end
    end

    describe "department scoped to the document's entity" do
      it "rejects a department belonging to another entity" do
        document.department = create(:department, entity: create(:entity))

        expect(document).not_to be_valid
        expect(document.errors[:department]).to be_present
      end

      it "accepts a department belonging to the same entity" do
        document.department = create(:department, entity: entity)

        expect(document).to be_valid
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

  describe "#sender_token and #addressee_token" do
    it "reads back as Type-id for a contact" do
      contact = create(:contact, entity: entity)
      document.sender = contact

      expect(document.sender_token).to eq("Contact-#{contact.id}")
    end

    it "assigns the polymorphic sender from a token" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user, status: "active")

      document.sender_token = "User-#{user.id}"

      expect(document.sender).to eq(user)
      expect(document.sender_type).to eq("User")
    end
  end

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

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe ".authored_by" do
    it "returns documents created by the given user" do
      author = create(:user)
      other = create(:user)
      mine = create(:document, entity: entity, created_by: author)
      create(:document, entity: entity, created_by: other)

      expect(Document.authored_by(author)).to contain_exactly(mine)
    end
  end

  describe ".received_by" do
    it "returns documents where the user is an actor on any workflow step, regardless of status" do
      user = create(:user)
      received = create(:document, entity: entity)
      create(:workflow_step, document: received, actor: user, status: "approved")

      not_received = create(:document, entity: entity)
      create(:workflow_step, document: not_received, actor: create(:user))

      expect(Document.received_by(user)).to contain_exactly(received)
    end

    it "does not return duplicate rows for a document with multiple steps assigned to the same user" do
      user = create(:user)
      document = create(:document, entity: entity)
      create(:workflow_step, document: document, actor: user, role: "RED", order: 1)
      create(:workflow_step, document: document, actor: user, role: "VISA", order: 2)

      expect(Document.received_by(user)).to contain_exactly(document)
    end
  end

  describe ".with_status" do
    it "filters by status when present" do
      draft = create(:document, entity: entity, status: "draft")
      create(:document, :in_progress, entity: entity)

      expect(Document.where(entity: entity).with_status("draft")).to contain_exactly(draft)
    end

    it "returns all documents when status is blank" do
      a = create(:document, entity: entity, status: "draft")
      b = create(:document, :in_progress, entity: entity)

      expect(Document.where(entity: entity).with_status(nil)).to contain_exactly(a, b)
      expect(Document.where(entity: entity).with_status("")).to contain_exactly(a, b)
    end
  end

  describe ".sorted" do
    it "defaults to document_date desc with created_at desc as a tiebreaker" do
      older = create(:document, entity: entity, document_date: Date.new(2025, 1, 1))
      newer = create(:document, entity: entity, document_date: Date.new(2025, 6, 1))

      expect(Document.where(entity: entity).sorted(nil, nil)).to eq([ newer, older ])
    end

    it "sorts by an explicit sortable column and direction" do
      a = create(:document, entity: entity, subject: "Alpha")
      b = create(:document, entity: entity, subject: "Beta")

      expect(Document.where(entity: entity).sorted("subject", "asc")).to eq([ a, b ])
      expect(Document.where(entity: entity).sorted("subject", "desc")).to eq([ b, a ])
    end

    it "falls back to the default column for an unknown column while respecting the given direction" do
      older = create(:document, entity: entity, document_date: Date.new(2025, 1, 1))
      newer = create(:document, entity: entity, document_date: Date.new(2025, 6, 1))

      expect(Document.where(entity: entity).sorted("not_a_column", "asc")).to eq([ older, newer ])
    end
  end
end
