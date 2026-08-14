# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::ResendDispatchOrganizer do
  let(:document) { create(:document) }
  let(:current_user) { create(:user) }

  describe ".call" do
    context "when resending to the addressee" do
      it "enqueues an addressee_notification job and logs dispatch_queued" do
        expect(AddresseeNotificationJob).to receive(:perform_later)
          .with(document.addressee_type, document.addressee_id, document.id, current_user.id)

        result = described_class.call(
          document: document, current_user: current_user,
          recipient_type: document.addressee_type, recipient_id: document.addressee_id
        )

        expect(result).to be_success
        expect(AuditLog.last.action).to eq("dispatch_queued")
      end
    end

    context "when the recipient is an internal user" do
      let(:internal_user) { create(:user) }
      let!(:cc_recipient) do
        create(:entity_user, entity: document.entity, user: internal_user, status: "active")
        create(:cc_recipient, document: document, party: internal_user)
      end

      it "fails without enqueuing any job" do
        expect(CcNotificationJob).not_to receive(:perform_later)

        result = described_class.call(
          document: document, current_user: current_user, recipient_type: "User", recipient_id: internal_user.id
        )

        expect(result).to be_failure
      end
    end

    context "when the recipient does not exist on the document" do
      it "fails" do
        result = described_class.call(
          document: document, current_user: current_user, recipient_type: "Contact", recipient_id: -1
        )

        expect(result).to be_failure
      end
    end
  end
end
