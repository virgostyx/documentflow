# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::CancelDocumentOrganizer do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:document) { create(:document, :in_progress, entity: entity, created_by: user) }

  describe ".call" do
    context "when the document can be cancelled" do
      it "cancels the document" do
        described_class.call(document: document, current_user: user, reason: "No longer needed")

        expect(document.reload).to be_cancelled
      end

      it "logs an audit event with the reason" do
        expect {
          described_class.call(document: document, current_user: user, reason: "No longer needed")
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("cancel_document")
        expect(audit_log.change_data["reason"]).to eq("No longer needed")
      end
    end

    context "when the document is already finalized" do
      let(:document) { create(:document, :finalized, entity: entity, created_by: user) }

      it "fails and does not cancel the document" do
        result = described_class.call(document: document, current_user: user, reason: "Too late")

        expect(result).not_to be_success
        expect(document.reload).to be_finalized
      end

      it "does not log an audit event" do
        expect {
          described_class.call(document: document, current_user: user, reason: "Too late")
        }.not_to change(AuditLog, :count)
      end
    end
  end
end
