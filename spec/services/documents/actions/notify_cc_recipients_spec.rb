# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::NotifyCcRecipients do
  let(:document) { create(:document) }

  let(:ctx) { LightService::Context.make(document: document) }

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
        expect(CcNotificationJob).to receive(:perform_later).with("User", user.id, document.id)
        expect(CcNotificationJob).to receive(:perform_later).with("Contact", contact.id, document.id)

        described_class.execute(ctx)
      end
    end

    context "when the document has no cc recipients" do
      it "does not enqueue any job" do
        expect(CcNotificationJob).not_to receive(:perform_later)

        described_class.execute(ctx)
      end
    end

    it "succeeds" do
      result = described_class.execute(ctx)

      expect(result).to be_success
    end
  end
end
