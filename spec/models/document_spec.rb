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
    it { is_expected.to have_many(:annexes).dependent(:destroy) }
    it { is_expected.to belong_to(:checked_out_by).class_name("User").optional }
    it { is_expected.to have_many(:document_file_versions) }
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

    describe "direction" do
      it "defaults to outgoing" do
        expect(Document.new.direction).to eq("outgoing")
      end

      %w[outgoing incoming].each do |direction|
        it "accepts #{direction}" do
          document.direction = direction
          expect(document).to be_valid
        end
      end

      it "rejects an unknown direction" do
        document.direction = "lateral"
        expect(document).not_to be_valid
        expect(document.errors[:direction]).to be_present
      end
    end

    describe "lead_user scoped to the document's entity" do
      it "rejects a lead_user not belonging to the entity" do
        document.lead_user = create(:user)

        expect(document).not_to be_valid
        expect(document.errors[:lead_user]).to be_present
      end

      it "accepts a lead_user who is an active member of the entity" do
        user = create(:user)
        create(:entity_user, entity: entity, user: user, status: "active")

        document.lead_user = user

        expect(document).to be_valid
      end

      it "accepts a blank lead_user" do
        document.lead_user = nil

        expect(document).to be_valid
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

    describe "classification_node scoped to the document's entity" do
      it "rejects a classification_node belonging to a different entity" do
        document.classification_node = create(:classification_node, entity: create(:entity), code: "1", name: "Root")

        expect(document).not_to be_valid
        expect(document.errors[:classification_node]).to be_present
      end

      it "accepts a classification_node belonging to the same entity" do
        document.classification_node = create(:classification_node, entity: entity, code: "1", name: "Root")

        expect(document).to be_valid
      end

      it "accepts a blank classification_node" do
        document.classification_node = nil

        expect(document).to be_valid
      end
    end
  end

  # ── Callbacks ─────────────────────────────────────────────────────────────

  describe "after_create :assign_temporary_number" do
    it "assigns a provisional PROV-<id> number to outgoing documents" do
      document.save!
      expect(document.temporary_number).to eq("PROV-#{document.id}")
    end

    it "does not assign a reference_number yet" do
      document.save!
      expect(document.reference_number).to be_nil
    end

    it "#display_number falls back to the temporary number" do
      document.save!
      expect(document.display_number).to eq(document.temporary_number)
    end
  end

  describe "before_validation :generate_reference_number (incoming mail only)" do
    it "assigns a reference number immediately, matching PREFIX(YYYY)#####" do
      doc = create(:document, :incoming, entity: entity)
      expect(doc.reference_number).to match(/\A[A-Z0-9]{1,8}\(\d{4}\)\d{5}\z/)
    end

    it "does not assign a temporary_number" do
      doc = create(:document, :incoming, entity: entity)
      expect(doc.temporary_number).to be_nil
    end

    it "does not regenerate an existing reference number" do
      doc = build(:document, :incoming, entity: entity, reference_number: "FIN(2020)00099")
      doc.valid?
      expect(doc.reference_number).to eq("FIN(2020)00099")
    end
  end

  describe "before_validation :generate_reference_number (archived_from_email outgoing documents)" do
    it "assigns a reference number immediately, matching PREFIX(YYYY)#####" do
      doc = create(:document, :archived_from_email, entity: entity)
      expect(doc.reference_number).to match(/\A[A-Z0-9]{1,8}\(\d{4}\)\d{5}\z/)
    end

    it "does not assign a temporary_number" do
      doc = create(:document, :archived_from_email, entity: entity)
      expect(doc.temporary_number).to be_nil
    end

    it "does not affect a normal outgoing document" do
      doc = create(:document, entity: entity)
      expect(doc.reference_number).to be_nil
      expect(doc.temporary_number).to be_present
    end
  end

  describe "#sign / after: :assign_reference_number" do
    it "assigns a reference number matching PREFIX(YYYY)##### when signed" do
      doc = create(:document, :in_progress, entity: entity)
      doc.sign!
      expect(doc.reference_number).to match(/\A[A-Z0-9]{1,8}\(\d{4}\)\d{5}\z/)
    end

    it "uses the department's prefix" do
      department = create(:department, entity: entity, prefix: "FIN")
      doc = create(:document, :in_progress, entity: entity, department: department)
      doc.sign!
      expect(doc.reference_number).to eq("FIN(#{Date.current.year})00001")
    end

    it "increments the sequence for the same department and year" do
      department = create(:department, entity: entity)
      first = create(:document, :in_progress, entity: entity, department: department)
      second = create(:document, :in_progress, entity: entity, department: department)
      first.sign!
      second.sign!
      expect(ReferenceNumber.parse(second.reference_number).sequence)
        .to eq(ReferenceNumber.parse(first.reference_number).sequence + 1)
    end

    it "keeps independent sequences for different departments in the same entity" do
      first_department = create(:department, entity: entity)
      second_department = create(:department, entity: entity)
      first = create(:document, :in_progress, entity: entity, department: first_department)
      second = create(:document, :in_progress, entity: entity, department: second_department)
      first.sign!
      second.sign!
      expect(ReferenceNumber.parse(first.reference_number).sequence).to eq(1)
      expect(ReferenceNumber.parse(second.reference_number).sequence).to eq(1)
    end

    it "resets the counter every year, based on the signature date rather than document_date" do
      department = create(:department, entity: entity, prefix: "FIN")
      travel_to(Date.new(2025, 12, 31)) do
        doc = create(:document, :in_progress, entity: entity, department: department, document_date: Date.new(2025, 12, 31))
        doc.sign!
      end
      travel_to(Date.new(2026, 1, 1)) do
        doc = create(:document, :in_progress, entity: entity, department: department, document_date: Date.new(2025, 12, 31))
        doc.sign!
        expect(doc.reference_number).to eq("FIN(2026)00001")
      end
    end

    it "does not regenerate an existing reference number" do
      doc = create(:document, :in_progress, entity: entity, reference_number: "FIN(2020)00099")
      doc.sign!
      expect(doc.reference_number).to eq("FIN(2020)00099")
    end

    it "clears the temporary_number's role once a definitive number exists (#display_number prefers it)" do
      doc = create(:document, :in_progress, entity: entity)
      doc.sign!
      expect(doc.display_number).to eq(doc.reference_number)
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

      it "freezes the document" do
        document = create(:document, :in_progress)
        document.sign!
        expect(document.is_frozen).to be true
      end

      it "cannot be signed from draft" do
        document.save!
        expect(document.may_sign?).to be false
      end
    end

    describe "#finalize" do
      it "transitions from signed to finalized" do
        document = create(:document, :signed)
        expect(document.finalize!).to be true
        expect(document).to be_finalized
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

  describe "#active_shared_link" do
    it "creates a shared link when none exists" do
      document.save!

      expect { document.active_shared_link }.to change(document.shared_links, :count).by(1)
      expect(document.active_shared_link).to be_active
    end

    it "reuses an existing active shared link instead of creating a new one" do
      document.save!
      existing = create(:shared_link, document: document)

      expect { document.active_shared_link }.not_to change(SharedLink, :count)
      expect(document.active_shared_link).to eq(existing)
    end

    it "ignores expired shared links and creates a new one" do
      document.save!
      create(:shared_link, :expired, document: document)

      expect { document.active_shared_link }.to change(document.shared_links, :count).by(1)
      expect(document.active_shared_link).to be_active
    end
  end

  describe "#any_external_recipients?" do
    let(:internal_user) do
      user = create(:user)
      create(:entity_user, entity: entity, user: user, status: "active")
      user
    end

    it "is true when the addressee is external" do
      document.addressee = create(:contact, entity: entity)
      document.save!

      expect(document.any_external_recipients?).to be true
    end

    it "is true when a cc recipient is external" do
      document.addressee = internal_user
      document.save!
      create(:cc_recipient, document: document, party: create(:contact, entity: entity))

      expect(document.any_external_recipients?).to be true
    end

    it "is false when every recipient is internal" do
      document.addressee = internal_user
      document.save!
      create(:cc_recipient, document: document, party: internal_user)

      expect(document.any_external_recipients?).to be false
    end
  end

  describe "#checked_out? and #checked_out_by? and #locked_for?" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    it "is not checked out by default" do
      document.save!
      expect(document.checked_out?).to be false
    end

    it "is checked out once checked_out_by is set" do
      document.save!
      document.update!(checked_out_by: user, checked_out_at: Time.current)
      expect(document.checked_out?).to be true
    end

    it "#checked_out_by? is true for the checking-out user" do
      document.save!
      document.update!(checked_out_by: user, checked_out_at: Time.current)
      expect(document.checked_out_by?(user)).to be true
      expect(document.checked_out_by?(other_user)).to be false
    end

    it "#locked_for? is false when not checked out" do
      document.save!
      expect(document.locked_for?(user)).to be false
    end

    it "#locked_for? is false for the checking-out user, true for anyone else" do
      document.save!
      document.update!(checked_out_by: user, checked_out_at: Time.current)
      expect(document.locked_for?(user)).to be false
      expect(document.locked_for?(other_user)).to be true
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

    it "excludes a document once the addressee has posted a finalized reply to it" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      original = create(:document, :expecting_response, entity: entity, addressee: user)
      create(:document, :finalized, entity: entity, created_by: user, in_reply_to: original)

      expect(Document.todo_for(user)).to be_empty
    end

    it "keeps a document in the todo list if the addressee's reply is not yet finalized" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      original = create(:document, :expecting_response, entity: entity, addressee: user)
      create(:document, entity: entity, created_by: user, in_reply_to: original)

      expect(Document.todo_for(user)).to contain_exactly(original)
    end

    it "keeps a document in the todo list if a finalized reply exists but was created by someone else" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      original = create(:document, :expecting_response, entity: entity, addressee: user)
      other_user = create(:user)
      create(:entity_user, entity: entity, user: other_user)
      create(:document, :finalized, entity: entity, created_by: other_user, in_reply_to: original)

      expect(Document.todo_for(user)).to contain_exactly(original)
    end

    it "excludes a document when only one of several replies from the addressee is finalized" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user)
      original = create(:document, :expecting_response, entity: entity, addressee: user)
      create(:document, entity: entity, created_by: user, in_reply_to: original)
      create(:document, :finalized, entity: entity, created_by: user, in_reply_to: original)

      expect(Document.todo_for(user)).to be_empty
    end

    it "returns a routed incoming document for the action assignee when a response is expected" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, lead_user: lead)

      expect(Document.todo_for(routed.addressee)).to contain_exactly(routed)
    end

    it "excludes a routed incoming document from the assignee's todo list once their reply is finalized" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, lead_user: lead)
      create(:document, :finalized, entity: entity, created_by: routed.addressee, in_reply_to: routed)

      expect(Document.todo_for(routed.addressee)).to be_empty
    end
  end

  describe ".pending_for" do
    it "returns documents where the user is the actor of the current (lowest-order) pending step" do
      user = create(:user)
      document = create(:document, :with_workflow, :in_progress, entity: entity)
      document.workflow_steps.find_by(role: "RED").update!(status: "approved")
      document.workflow_steps.find_by(role: "VISA").update!(actor: user)

      expect(Document.pending_for(user)).to contain_exactly(document)
    end

    it "excludes documents where the user is the actor of a later pending step while an earlier step is still pending" do
      user = create(:user)
      document = create(:document, :with_workflow, :in_progress, entity: entity)
      document.workflow_steps.find_by(role: "SIGN").update!(actor: user)

      expect(Document.pending_for(user)).to be_empty
    end

    it "excludes documents where the user's step has already been approved" do
      user = create(:user)
      document = create(:document, :with_workflow, :in_progress, entity: entity)
      document.workflow_steps.find_by(role: "RED").update!(actor: user, status: "approved")

      expect(Document.pending_for(user)).to be_empty
    end

    it "excludes documents where the user is not a workflow step actor" do
      user = create(:user)
      create(:document, :with_workflow, :in_progress, entity: entity)

      expect(Document.pending_for(user)).to be_empty
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

    it "excludes a document once it has received a finalized reply" do
      user = create(:user)
      original = create(:document, :expecting_response, entity: entity, created_by: user)
      create(:document, :finalized, entity: entity, in_reply_to: original)

      expect(Document.waiting_for(user)).to be_empty
    end

    it "keeps a document in the waiting list if the reply is not yet finalized" do
      user = create(:user)
      original = create(:document, :expecting_response, entity: entity, created_by: user)
      create(:document, entity: entity, in_reply_to: original)

      expect(Document.waiting_for(user)).to contain_exactly(original)
    end

    it "excludes a document when only one of several replies is finalized" do
      user = create(:user)
      original = create(:document, :expecting_response, entity: entity, created_by: user)
      create(:document, entity: entity, in_reply_to: original)
      create(:document, :finalized, entity: entity, in_reply_to: original)

      expect(Document.waiting_for(user)).to be_empty
    end

    it "returns a routed incoming document for the lead, not the registrant, when a response is expected" do
      lead = create(:user)
      registrant = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, lead_user: lead, created_by: registrant)

      expect(Document.waiting_for(lead)).to contain_exactly(routed)
      expect(Document.waiting_for(registrant)).to be_empty
    end

    it "excludes a routed incoming document from the lead's waiting list when no response is expected" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      create(:document, :incoming, :routed, entity: entity, lead_user: lead)

      expect(Document.waiting_for(lead)).to be_empty
    end

    it "excludes a routed incoming document once a finalized reply exists" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, lead_user: lead)
      create(:document, :finalized, entity: entity, in_reply_to: routed)

      expect(Document.waiting_for(lead)).to be_empty
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

    it "returns a routed incoming document for the lead when no response is expected" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      routed = create(:document, :incoming, :routed, entity: entity, lead_user: lead)

      expect(Document.info_for(lead)).to contain_exactly(routed)
    end

    it "returns a routed incoming document for the action assignee when no response is expected" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      routed = create(:document, :incoming, :routed, entity: entity, lead_user: lead)

      expect(Document.info_for(routed.addressee)).to contain_exactly(routed)
    end

    it "excludes a routed incoming document from the lead's info list when a response is expected" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      create(:document, :incoming, :routed, :expecting_response, entity: entity, lead_user: lead)

      expect(Document.info_for(lead)).to be_empty
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

  describe ".in_classification_node" do
    it "returns documents classified under the given node" do
      node = create(:classification_node, entity: entity, code: "1", name: "Root")
      classified = create(:document, entity: entity, department: document.department, classification_node: node)
      create(:document, entity: entity, department: document.department)

      expect(Document.where(entity: entity).in_classification_node(node)).to contain_exactly(classified)
    end
  end

  describe ".unclassified" do
    it "returns documents with no classification_node" do
      node = create(:classification_node, entity: entity, code: "1", name: "Root")
      create(:document, entity: entity, department: document.department, classification_node: node)
      unclassified = create(:document, entity: entity, department: document.department)

      expect(Document.where(entity: entity).unclassified).to contain_exactly(unclassified)
    end
  end

  describe ".incoming and .outgoing" do
    it "splits documents by direction" do
      incoming = create(:document, :incoming, entity: entity)
      outgoing = create(:document, entity: entity)

      expect(Document.where(entity: entity).incoming).to contain_exactly(incoming)
      expect(Document.where(entity: entity).outgoing).to contain_exactly(outgoing)
    end
  end

  describe ".settled" do
    it "returns a finalized outgoing document" do
      finalized = create(:document, :finalized, entity: entity)

      expect(Document.where(entity: entity).settled).to contain_exactly(finalized)
    end

    it "excludes an outgoing document that is not finalized" do
      create(:document, :in_progress, entity: entity)

      expect(Document.where(entity: entity).settled).to be_empty
    end

    it "returns a routed incoming document" do
      routed = create(:document, :incoming, :routed, entity: entity)

      expect(Document.where(entity: entity).settled).to contain_exactly(routed)
    end

    it "excludes an unrouted incoming document even if its status is finalized" do
      create(:document, :incoming, entity: entity, status: "finalized", routed_at: nil)

      expect(Document.where(entity: entity).settled).to be_empty
    end
  end

  describe ".pending_triage_for" do
    it "returns incoming documents where the user is the lead and routing hasn't happened yet" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      pending = create(:document, :incoming, entity: entity, lead_user: lead)

      expect(Document.where(entity: entity).pending_triage_for(lead)).to contain_exactly(pending)
    end

    it "excludes documents that have already been routed" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      create(:document, :incoming, entity: entity, lead_user: lead, routed_at: Time.current)

      expect(Document.where(entity: entity).pending_triage_for(lead)).to be_empty
    end

    it "excludes outgoing documents" do
      lead = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      create(:document, entity: entity, addressee: lead)

      expect(Document.where(entity: entity).pending_triage_for(lead)).to be_empty
    end

    it "excludes incoming documents where the user is not the lead" do
      lead = create(:user)
      other = create(:user)
      create(:entity_user, entity: entity, user: lead, status: "active")
      create(:entity_user, entity: entity, user: other, status: "active")
      create(:document, :incoming, entity: entity, lead_user: other, addressee: other)

      expect(Document.where(entity: entity).pending_triage_for(lead)).to be_empty
    end
  end

  describe "#routed?" do
    it "is false when routed_at is blank" do
      expect(build(:document, entity: entity, routed_at: nil).routed?).to be false
    end

    it "is true when routed_at is set" do
      expect(build(:document, entity: entity, routed_at: Time.current).routed?).to be true
    end
  end

  describe "#incoming? and #outgoing?" do
    it "reflects the direction column" do
      expect(build(:document, entity: entity, direction: "incoming")).to be_incoming
      expect(build(:document, entity: entity, direction: "incoming")).not_to be_outgoing
      expect(build(:document, entity: entity, direction: "outgoing")).to be_outgoing
      expect(build(:document, entity: entity, direction: "outgoing")).not_to be_incoming
    end
  end
end
