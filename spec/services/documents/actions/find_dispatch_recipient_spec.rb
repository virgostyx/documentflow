# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::FindDispatchRecipient do
  let(:document) { create(:document) }

  describe ".execute" do
    context "when the recipient matches the document's addressee" do
      let(:ctx) do
        LightService::Context.make(
          document: document, recipient_type: document.addressee_type, recipient_id: document.addressee_id
        )
      end

      it "resolves the addressee as the party" do
        result = described_class.execute(ctx)

        expect(result.party).to eq(document.addressee)
        expect(result.dispatch_channel).to eq(:addressee)
      end

      it "succeeds" do
        result = described_class.execute(ctx)

        expect(result).to be_success
      end
    end

    context "when the recipient matches an external cc recipient" do
      let(:contact) { create(:contact, entity: document.entity) }
      let!(:cc_recipient) { create(:cc_recipient, document: document, party: contact) }

      let(:ctx) do
        LightService::Context.make(document: document, recipient_type: "Contact", recipient_id: contact.id)
      end

      it "resolves the cc recipient's party" do
        result = described_class.execute(ctx)

        expect(result.party).to eq(contact)
        expect(result.dispatch_channel).to eq(:cc)
      end
    end

    context "when the recipient matches an internal cc recipient" do
      let(:user) { create(:user) }
      let!(:cc_recipient) do
        create(:entity_user, entity: document.entity, user: user, status: "active")
        create(:cc_recipient, document: document, party: user)
      end

      let(:ctx) do
        LightService::Context.make(document: document, recipient_type: "User", recipient_id: user.id)
      end

      it "fails" do
        result = described_class.execute(ctx)

        expect(result).to be_failure
      end
    end

    context "when no recipient matches" do
      let(:ctx) do
        LightService::Context.make(document: document, recipient_type: "Contact", recipient_id: -1)
      end

      it "fails" do
        result = described_class.execute(ctx)

        expect(result).to be_failure
      end
    end
  end
end
