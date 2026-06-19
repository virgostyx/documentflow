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
    it { is_expected.to belong_to(:in_reply_to).class_name("Document").optional }
    it { is_expected.to have_many(:replies).class_name("Document") }
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

    describe "in_reply_to scoped to the document's entity" do
      it "rejects an in_reply_to document belonging to another entity" do
        document.in_reply_to = create(:document, entity: create(:entity))

        expect(document).not_to be_valid
        expect(document.errors[:in_reply_to]).to be_present
      end

      it "accepts an in_reply_to document belonging to the same entity" do
        document.in_reply_to = create(:document, entity: entity)

        expect(document).to be_valid
      end

      it "accepts a blank in_reply_to" do
        document.in_reply_to = nil

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

  describe "#awaiting_response_from?" do
    it "returns true when the user is the addressee and a response is expected" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      document = create(:document, :expecting_response, entity: entity, addressee: user)

      expect(document.awaiting_response_from?(user)).to be true
    end

    it "returns false when the user is the addressee but no response is expected" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      document = create(:document, entity: entity, addressee: user)

      expect(document.awaiting_response_from?(user)).to be false
    end

    it "returns false when a response is expected but the user is not the addressee" do
      user = create(:user)
      document = create(:document, :expecting_response, entity: entity)

      expect(document.awaiting_response_from?(user)).to be false
    end

    it "returns false when the addressee is a contact, not the given user" do
      user = create(:user)
      document = create(:document, :expecting_response, entity: entity, addressee: create(:contact, entity: entity))

      expect(document.awaiting_response_from?(user)).to be false
    end
  end

  describe "#thread" do
    it "returns the full chain in chronological order, regardless of which document it's called on" do
      a = create(:document, entity: entity, document_date: Date.new(2026, 1, 1))
      b = create(:document, entity: entity, in_reply_to: a, document_date: Date.new(2026, 1, 5))
      c = create(:document, entity: entity, in_reply_to: b, document_date: Date.new(2026, 1, 10))

      expect(a.thread).to eq([ a, b, c ])
      expect(b.thread).to eq([ a, b, c ])
      expect(c.thread).to eq([ a, b, c ])
    end

    it "returns just itself when it has no replies and is not a reply" do
      standalone = create(:document, entity: entity)

      expect(standalone.thread).to eq([ standalone ])
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

  describe "#expects_response" do
    it "defaults to false" do
      expect(build(:document, entity: entity).expects_response).to be false
    end

    it "can be set to true and persists" do
      document = create(:document, entity: entity, expects_response: true)
      expect(document.reload.expects_response).to be true
    end
  end

  describe "#response_deadline" do
    it "can be set when expects_response is true" do
      document = create(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 1))

      expect(document.reload.response_deadline).to eq(Date.new(2026, 7, 1))
    end

    it "is cleared when expects_response is false" do
      document = build(:document, entity: entity, expects_response: false, response_deadline: Date.new(2026, 7, 1))

      document.save!

      expect(document.reload.response_deadline).to be_nil
    end

    it "is cleared when expects_response is toggled off on an existing document" do
      document = create(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 1))

      document.update!(expects_response: false)

      expect(document.reload.response_deadline).to be_nil
    end
  end

  describe "#deadline_overdue?" do
    it "is false when there is no response_deadline" do
      document = build(:document, entity: entity, expects_response: false, response_deadline: nil)

      expect(document.deadline_overdue?).to be false
    end

    it "is false when the deadline is in the future" do
      travel_to Date.new(2026, 7, 1) do
        document = build(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 2))

        expect(document.deadline_overdue?).to be false
      end
    end

    it "is true when the deadline is today" do
      travel_to Date.new(2026, 7, 1) do
        document = build(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 1))

        expect(document.deadline_overdue?).to be true
      end
    end

    it "is true when the deadline is in the past" do
      travel_to Date.new(2026, 7, 2) do
        document = build(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 1))

        expect(document.deadline_overdue?).to be true
      end
    end
  end

  describe "#deadline_due_tomorrow?" do
    it "is false when there is no response_deadline" do
      document = build(:document, entity: entity, expects_response: false, response_deadline: nil)

      expect(document.deadline_due_tomorrow?).to be false
    end

    it "is true when the deadline is tomorrow" do
      travel_to Date.new(2026, 7, 1) do
        document = build(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 2))

        expect(document.deadline_due_tomorrow?).to be true
      end
    end

    it "is false when the deadline is today" do
      travel_to Date.new(2026, 7, 1) do
        document = build(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 1))

        expect(document.deadline_due_tomorrow?).to be false
      end
    end

    it "is false when the deadline is more than a day away" do
      travel_to Date.new(2026, 7, 1) do
        document = build(:document, entity: entity, expects_response: true, response_deadline: Date.new(2026, 7, 3))

        expect(document.deadline_due_tomorrow?).to be false
      end
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
    it "returns documents where the user is the addressee" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      received = create(:document, entity: entity, addressee: user)
      not_received = create(:document, entity: entity)

      expect(Document.received_by(user)).to contain_exactly(received)
    end

    it "returns documents where the user is a cc recipient" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      other_user = create(:user)
      create(:entity_user, entity: entity, user: other_user)

      received = create(:document, entity: entity)
      create(:cc_recipient, document: received, party: user)

      not_received = create(:document, entity: entity)
      create(:cc_recipient, document: not_received, party: other_user)

      expect(Document.received_by(user)).to contain_exactly(received)
    end

    it "does not return duplicate rows for a document where the user is both addressee and cc recipient" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      document = create(:document, entity: entity, addressee: user)
      create(:cc_recipient, document: document, party: user)

      expect(Document.received_by(user)).to contain_exactly(document)
    end
  end

  describe ".todo_for" do
    it "returns documents where the user is the addressee and expects a response" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      todo = create(:document, :expecting_response, entity: entity, addressee: user)

      expect(Document.todo_for(user)).to contain_exactly(todo)
    end

    it "excludes documents where the user is the addressee but no response is expected" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      create(:document, entity: entity, addressee: user)

      expect(Document.todo_for(user)).to be_empty
    end

    it "excludes documents where the user is only a cc recipient, even if a response is expected" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      document = create(:document, :expecting_response, entity: entity)
      create(:cc_recipient, document: document, party: user)

      expect(Document.todo_for(user)).to be_empty
    end

    it "excludes documents authored by the user where a response is expected" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      create(:document, :expecting_response, entity: entity, created_by: user)

      expect(Document.todo_for(user)).to be_empty
    end
  end

  describe ".waiting_for" do
    it "returns documents authored by the user where a response is expected" do
      user = create(:user)
      waiting = create(:document, :expecting_response, entity: entity, created_by: user)

      expect(Document.waiting_for(user)).to contain_exactly(waiting)
    end

    it "excludes documents authored by the user where no response is expected" do
      user = create(:user)
      create(:document, entity: entity, created_by: user)

      expect(Document.waiting_for(user)).to be_empty
    end

    it "excludes documents expecting a response that were authored by someone else" do
      user = create(:user)
      create(:document, :expecting_response, entity: entity, created_by: create(:user))

      expect(Document.waiting_for(user)).to be_empty
    end
  end

  describe ".info_for" do
    it "returns documents where the user is a cc recipient, regardless of expects_response" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      document = create(:document, :expecting_response, entity: entity)
      create(:cc_recipient, document: document, party: user)

      expect(Document.info_for(user)).to contain_exactly(document)
    end

    it "returns documents where the user is the addressee and no response is expected" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      document = create(:document, entity: entity, addressee: user)

      expect(Document.info_for(user)).to contain_exactly(document)
    end

    it "returns documents authored by the user where no response is expected" do
      user = create(:user)
      document = create(:document, entity: entity, created_by: user)

      expect(Document.info_for(user)).to contain_exactly(document)
    end

    it "excludes documents where the user is the addressee and a response is expected" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      create(:document, :expecting_response, entity: entity, addressee: user)

      expect(Document.info_for(user)).to be_empty
    end

    it "excludes documents authored by the user where a response is expected" do
      user = create(:user)
      create(:document, :expecting_response, entity: entity, created_by: user)

      expect(Document.info_for(user)).to be_empty
    end

    it "excludes unrelated documents" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      create(:document, entity: entity)

      expect(Document.info_for(user)).to be_empty
    end

    it "does not return duplicate rows for a document where the user is both addressee and cc recipient" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      document = create(:document, entity: entity, addressee: user)
      create(:cc_recipient, document: document, party: user)

      expect(Document.info_for(user)).to contain_exactly(document)
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
