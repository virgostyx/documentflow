# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::NotifyAddressee do
  let(:document) { create(:document) }
  let(:current_user) { create(:user) }

  let(:ctx) { LightService::Context.make(document: document, current_user: current_user) }

  describe ".execute" do
    it "enqueues an addressee_notification job for the document's addressee" do
      expect(AddresseeNotificationJob).to receive(:perform_later)
        .with(document.addressee_type, document.addressee_id, document.id, current_user.id)

      described_class.execute(ctx)
    end

    it "logs a dispatch_queued audit event for the addressee" do
      expect { described_class.execute(ctx) }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("dispatch_queued")
      expect(log.user).to eq(current_user)
      expect(log.auditable).to eq(document)
      expect(log.change_data["recipient_type"]).to eq(document.addressee_type)
      expect(log.change_data["recipient_id"]).to eq(document.addressee_id)
    end

    it "succeeds" do
      result = described_class.execute(ctx)

      expect(result).to be_success
    end
  end
end
