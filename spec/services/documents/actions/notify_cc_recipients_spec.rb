# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::NotifyCcRecipients do
  let(:document) { create(:document) }
  let(:current_user) { create(:user) }

  let(:ctx) { LightService::Context.make(document: document, current_user: current_user) }

  describe ".execute" do
    context "when the document has cc recipients" do
      let(:user) { create(:user) }
      let(:contact) { create(:contact, entity: document.entity) }

      before do
        create(:entity_user, entity: document.entity, user: user, status: "active")
        create(:cc_recipient, document: document, party: user)
        create(:cc_recipient, document: document, party: contact)
      end

      it "enqueues a cc_notification job for each recipient" do
        expect(CcNotificationJob).to receive(:perform_later).with("User", user.id, document.id, current_user.id)
        expect(CcNotificationJob).to receive(:perform_later).with("Contact", contact.id, document.id, current_user.id)

        described_class.execute(ctx)
      end

      it "logs a dispatch_queued audit event for each recipient" do
        expect { described_class.execute(ctx) }.to change(AuditLog, :count).by(2)

        actions = AuditLog.where(auditable: document).pluck(:action)
        expect(actions).to eq(%w[dispatch_queued dispatch_queued])
      end
    end

    context "when the document has no cc recipients" do
      it "does not enqueue any job" do
        expect(CcNotificationJob).not_to receive(:perform_later)

        described_class.execute(ctx)
      end

      it "does not log any audit event" do
        expect { described_class.execute(ctx) }.not_to change(AuditLog, :count)
      end
    end

    it "succeeds" do
      result = described_class.execute(ctx)

      expect(result).to be_success
    end
  end
end
