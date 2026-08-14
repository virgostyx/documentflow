# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::ResendDispatchNotification do
  let(:document) { create(:document) }
  let(:current_user) { create(:user) }
  let(:contact) { document.addressee }

  describe ".execute" do
    context "when resending to the addressee" do
      let(:ctx) do
        LightService::Context.make(
          document: document, current_user: current_user, party: contact, dispatch_channel: :addressee,
          recipient_type: document.addressee_type, recipient_id: document.addressee_id
        )
      end

      it "enqueues an addressee_notification job" do
        expect(AddresseeNotificationJob).to receive(:perform_later)
          .with(document.addressee_type, document.addressee_id, document.id, current_user.id)

        described_class.execute(ctx)
      end

      it "logs a fresh dispatch_queued audit event" do
        expect { described_class.execute(ctx) }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("dispatch_queued")
        expect(log.user).to eq(current_user)
        expect(log.auditable).to eq(document)
        expect(log.change_data["recipient_type"]).to eq(document.addressee_type)
        expect(log.change_data["recipient_id"]).to eq(document.addressee_id)
        expect(log.change_data["recipient_email"]).to eq(contact.email)
      end

      it "succeeds" do
        result = described_class.execute(ctx)

        expect(result).to be_success
      end
    end

    context "when resending to a cc recipient" do
      let(:cc_contact) { create(:contact, entity: document.entity) }
      let!(:cc_recipient) { create(:cc_recipient, document: document, party: cc_contact) }

      let(:ctx) do
        LightService::Context.make(
          document: document, current_user: current_user, party: cc_contact, dispatch_channel: :cc,
          recipient_type: "Contact", recipient_id: cc_contact.id
        )
      end

      it "enqueues a cc_notification job" do
        expect(CcNotificationJob).to receive(:perform_later).with("Contact", cc_contact.id, document.id, current_user.id)

        described_class.execute(ctx)
      end
    end
  end
end
