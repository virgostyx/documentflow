# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedLinks::RequestRenewal do
  let(:document) { create(:document, :finalized) }
  let!(:expired_link) { create(:shared_link, :expired, document: document) }

  describe ".call" do
    context "when the email matches the document's external addressee" do
      it "enqueues an addressee notification and returns true" do
        expect(AddresseeNotificationJob).to receive(:perform_later)
          .with("Contact", document.addressee_id, document.id)

        result = described_class.call(token: expired_link.token, email: document.addressee.email)

        expect(result).to be true
      end

      it "creates a new active shared link for the document" do
        expect {
          described_class.call(token: expired_link.token, email: document.addressee.email)
        }.to change { document.shared_links.active.count }.by(1)
      end

      it "marks the document's shared link as renewed" do
        expect {
          described_class.call(token: expired_link.token, email: document.addressee.email)
        }.to change { document.reload.shared_link_renewed_at }.from(nil)
      end

      it "matches case-insensitively and ignores surrounding whitespace" do
        expect(AddresseeNotificationJob).to receive(:perform_later)

        result = described_class.call(token: expired_link.token, email: " #{document.addressee.email.upcase} ")

        expect(result).to be true
      end
    end

    context "when the email matches an external cc recipient" do
      let(:contact) { create(:contact, entity: document.entity) }

      before { create(:cc_recipient, document: document, party: contact) }

      it "enqueues a cc notification and returns true" do
        expect(CcNotificationJob).to receive(:perform_later).with("Contact", contact.id, document.id)

        result = described_class.call(token: expired_link.token, email: contact.email)

        expect(result).to be true
      end
    end

    context "when the email does not match any external recipient of the document" do
      it "does not enqueue any notification and returns false" do
        expect(AddresseeNotificationJob).not_to receive(:perform_later)
        expect(CcNotificationJob).not_to receive(:perform_later)

        result = described_class.call(token: expired_link.token, email: "nobody@example.com")

        expect(result).to be false
      end
    end

    context "when the addressee is an internal user" do
      let(:document) { create(:document, :finalized, :incoming) }

      it "does not enqueue any notification and returns false" do
        expect(AddresseeNotificationJob).not_to receive(:perform_later)

        result = described_class.call(token: expired_link.token, email: document.addressee.email)

        expect(result).to be false
      end
    end

    context "when the token is unknown" do
      it "does not enqueue any notification and returns false" do
        expect(AddresseeNotificationJob).not_to receive(:perform_later)

        result = described_class.call(token: "unknown-token", email: document.addressee.email)

        expect(result).to be false
      end
    end

    context "when the document's shared link has already been renewed once" do
      before { document.update!(shared_link_renewed_at: 1.day.ago) }

      it "does not enqueue another notification and returns false" do
        expect(AddresseeNotificationJob).not_to receive(:perform_later)
        expect(CcNotificationJob).not_to receive(:perform_later)

        result = described_class.call(token: expired_link.token, email: document.addressee.email)

        expect(result).to be false
      end

      it "does not enqueue another notification even for a different matching external recipient" do
        contact = create(:contact, entity: document.entity)
        create(:cc_recipient, document: document, party: contact)

        expect(CcNotificationJob).not_to receive(:perform_later)

        result = described_class.call(token: expired_link.token, email: contact.email)

        expect(result).to be false
      end
    end
  end
end
