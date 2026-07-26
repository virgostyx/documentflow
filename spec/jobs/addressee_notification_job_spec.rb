# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddresseeNotificationJob do
  let(:document) { create(:document) }

  describe "#perform" do
    context "with an internal user recipient" do
      let(:user) { create(:user) }

      it "delivers a document_addressed notification to the user" do
        expect(NotificationMailer).to receive(:document_addressed)
          .with(user, document)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

        described_class.new.perform("User", user.id, document.id)
      end
    end

    context "with an external contact recipient" do
      let(:contact) { create(:contact, entity: document.entity) }

      it "delivers a document_addressed notification to the contact" do
        expect(NotificationMailer).to receive(:document_addressed)
          .with(contact, document)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

        described_class.new.perform("Contact", contact.id, document.id)
      end
    end
  end
end
