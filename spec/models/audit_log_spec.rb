# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog, type: :model do
  subject(:audit_log) { build(:audit_log) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:auditable) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:action) }
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe "scopes" do
    let(:document) { create(:document) }
    let(:user)     { create(:user) }
    let(:other_user) { create(:user) }

    let!(:create_log)   { create(:audit_log, user: user, auditable: document, action: "document_created") }
    let!(:launch_log)   { create(:audit_log, user: user, auditable: document, action: "document_launched") }
    let!(:other_log)    { create(:audit_log, user: other_user, auditable: document, action: "document_created") }

    describe ".for_user" do
      it "returns logs for the given user" do
        expect(AuditLog.for_user(user.id)).to include(create_log, launch_log)
        expect(AuditLog.for_user(user.id)).not_to include(other_log)
      end
    end

    describe ".for_auditable" do
      it "returns logs for the given auditable record" do
        other_document = create(:document)
        unrelated_log = create(:audit_log, user: user, auditable: other_document)

        expect(AuditLog.for_auditable(document)).to include(create_log, launch_log, other_log)
        expect(AuditLog.for_auditable(document)).not_to include(unrelated_log)
      end
    end

    describe ".for_action" do
      it "returns logs matching the given action" do
        expect(AuditLog.for_action("document_created")).to include(create_log, other_log)
        expect(AuditLog.for_action("document_created")).not_to include(launch_log)
      end
    end

    describe ".recent" do
      it "orders logs by creation date, newest first" do
        expect(AuditLog.recent.to_a).to eq([ other_log, launch_log, create_log ])
      end
    end
  end

  # ── Class methods ─────────────────────────────────────────────────────────

  describe ".log_event" do
    it "creates an audit log with the given attributes" do
      user = create(:user)
      document = create(:document)

      expect {
        described_class.log_event(user: user, auditable: document, action: "document_created", changes: { status: "draft" })
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.user).to eq(user)
      expect(log.auditable).to eq(document)
      expect(log.action).to eq("document_created")
      expect(log.change_data).to eq({ "status" => "draft" })
    end
  end

  # ── Instance methods ──────────────────────────────────────────────────────

  describe "#summary" do
    it "summarizes the event" do
      user = create(:user, email: "jean@example.com")
      document = create(:document)
      log = create(:audit_log, user: user, auditable: document, action: "document_created")

      expect(log.summary).to eq("jean@example.com document_created Document##{document.id}")
    end
  end
end
