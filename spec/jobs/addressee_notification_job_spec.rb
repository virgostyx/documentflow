# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddresseeNotificationJob do
  let(:document) { create(:document) }
  let(:acting_user) { create(:user) }

  describe "#perform" do
    context "with an internal user recipient" do
      let(:user) { create(:user) }

      it "delivers a document_addressed notification to the user" do
        expect(NotificationMailer).to receive(:document_addressed)
          .with(user, document)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

        described_class.new.perform("User", user.id, document.id, acting_user.id)
      end
    end

    context "with an external contact recipient" do
      let(:contact) { create(:contact, entity: document.entity) }

      it "delivers a document_addressed notification to the contact" do
        expect(NotificationMailer).to receive(:document_addressed)
          .with(contact, document)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

        described_class.new.perform("Contact", contact.id, document.id, acting_user.id)
      end
    end

    context "when delivery succeeds" do
      let(:contact) { create(:contact, entity: document.entity) }

      before do
        allow(NotificationMailer).to receive(:document_addressed)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))
      end

      it "logs a dispatch_sent audit event" do
        expect {
          described_class.new.perform("Contact", contact.id, document.id, acting_user.id)
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("dispatch_sent")
        expect(log.user).to eq(acting_user)
        expect(log.auditable).to eq(document)
        expect(log.change_data["recipient_email"]).to eq(contact.email)
      end
    end

    context "when delivery fails" do
      let(:contact) { create(:contact, entity: document.entity) }

      before do
        allow(NotificationMailer).to receive(:document_addressed).and_raise(StandardError, "SMTP timeout")
      end

      it "logs a dispatch_failed audit event with the error message" do
        expect {
          described_class.new.perform("Contact", contact.id, document.id, acting_user.id)
        }.to raise_error(StandardError, "SMTP timeout").and change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("dispatch_failed")
        expect(log.change_data["error"]).to eq("SMTP timeout")
      end
    end
  end
end
