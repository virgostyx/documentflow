# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::CreateCcRecipients do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, entity: entity) }
  let(:internal_user) { create(:user) }
  let(:external_contact) { create(:contact, entity: entity) }

  let(:ctx) { LightService::Context.make(document: document, cc_party_tokens: cc_party_tokens) }

  before { create(:entity_user, entity: entity, user: internal_user, status: "active") }

  describe ".execute" do
    context "with a mix of internal and external party tokens" do
      let(:cc_party_tokens) { [ "User-#{internal_user.id}", "Contact-#{external_contact.id}" ] }

      it "creates a cc_recipient per token" do
        expect { described_class.execute(ctx) }.to change(document.cc_recipients, :count).by(2)
      end

      it "resolves each token to the correct party" do
        described_class.execute(ctx)
        expect(document.cc_recipients.reload.map(&:party)).to contain_exactly(internal_user, external_contact)
      end

      it "succeeds" do
        result = described_class.execute(ctx)
        expect(result).to be_success
      end
    end

    context "with blank tokens mixed in" do
      let(:cc_party_tokens) { [ "User-#{internal_user.id}", "", nil ] }

      it "ignores the blank entries" do
        expect { described_class.execute(ctx) }.to change(document.cc_recipients, :count).by(1)
      end
    end

    context "with an empty list" do
      let(:cc_party_tokens) { [] }

      it "creates no cc_recipients" do
        expect { described_class.execute(ctx) }.not_to change(document.cc_recipients, :count)
      end

      it "succeeds" do
        result = described_class.execute(ctx)
        expect(result).to be_success
      end
    end

    context "when cc_party_tokens is nil" do
      let(:cc_party_tokens) { nil }

      it "does not raise and creates no cc_recipients" do
        expect { described_class.execute(ctx) }.not_to change(document.cc_recipients, :count)
      end
    end

    context "with a party that does not belong to the document's entity" do
      let(:outsider_contact) { create(:contact, entity: create(:entity)) }
      let(:cc_party_tokens) { [ "Contact-#{outsider_contact.id}" ] }

      it "fails instead of raising" do
        result = described_class.execute(ctx)
        expect(result).to be_failure
      end

      it "does not create the invalid cc_recipient" do
        expect { described_class.execute(ctx) }.not_to change(document.cc_recipients, :count)
      end
    end
  end
end
