# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::DestroyDocumentOrganizer do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:document) { create(:document, entity: entity, created_by: user, subject: "Supplier agreement") }

  describe ".call" do
    it "destroys the document" do
      described_class.call(document: document, current_user: user, reason: "Created by mistake")

      expect(Document.exists?(document.id)).to be false
    end

    it "logs an audit event with the reason and a snapshot of the document" do
      expect {
        described_class.call(document: document, current_user: user, reason: "Created by mistake")
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq("destroy_document")
      expect(audit_log.change_data["reason"]).to eq("Created by mistake")
      expect(audit_log.change_data["subject"]).to eq("Supplier agreement")
    end

    it "preserves audit logs created before the deletion, unlinked from the now-gone document" do
      prior_log = AuditLog.log_event(user: user, auditable: document, action: "launch", changes: {})

      described_class.call(document: document, current_user: user, reason: "Created by mistake")

      expect(AuditLog.exists?(prior_log.id)).to be true
      expect(prior_log.reload.auditable_id).to be_nil
      expect(prior_log.reload.auditable_type).to be_nil
    end
  end
end
