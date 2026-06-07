# frozen_string_literal: true

require "rails_helper"

RSpec.describe Shared::Actions::LogAuditEvent do
  let(:user) { create(:user) }
  let(:document) { create(:document) }

  let(:ctx) do
    LightService::Context.make(
      user: user,
      auditable: document,
      action: "create",
      audit_changes: { subject: document.subject }
    )
  end

  describe ".execute" do
    it "creates an audit log" do
      expect {
        described_class.execute(ctx)
      }.to change(AuditLog, :count).by(1)
    end

    it "marks audit_logged as true and stores the audit log in the context" do
      result = described_class.execute(ctx)
      expect(result.audit_logged).to be true
      expect(result[:audit_log]).to be_a(AuditLog)
      expect(result[:audit_log].action).to eq("create")
      expect(result[:audit_log].auditable).to eq(document)
      expect(result[:audit_log].user).to eq(user)
    end

    context "when the audit log creation fails" do
      before do
        allow(AuditLog).to receive(:log_event).and_raise(StandardError.new("DB down"))
      end

      it "does not fail the workflow but marks audit_logged as false" do
        result = described_class.execute(ctx)

        expect(result).to be_success
        expect(result.audit_logged).to be false
        expect(result[:audit_log]).to be_nil
      end
    end
  end
end
