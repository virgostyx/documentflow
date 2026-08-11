# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::CreateCcRecipientsFromDistributionListMembers do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, entity: entity) }
  let(:internal_user) { create(:user) }
  let(:external_contact) { create(:contact, entity: entity) }
  let(:distribution_list) { create(:distribution_list) }

  let(:ctx) { LightService::Context.make(document: document, distribution_list_members: members) }

  before { create(:entity_user, entity: entity, user: internal_user, status: "active") }

  describe ".execute" do
    context "with a mix of internal and external members" do
      let(:members) do
        [
          create(:distribution_list_member, distribution_list: distribution_list, party: internal_user, position: 1,
                 dispatch_as_attachment: true),
          create(:distribution_list_member, distribution_list: distribution_list, party: external_contact, position: 2)
        ]
      end

      it "creates a cc_recipient per member" do
        expect { described_class.execute(ctx) }.to change(document.cc_recipients, :count).by(2)
      end

      it "carries over each member's dispatch_as_attachment default" do
        described_class.execute(ctx)
        recipient = document.cc_recipients.reload.find_by(party: internal_user)
        expect(recipient.dispatch_as_attachment).to be true
      end

      it "succeeds" do
        expect(described_class.execute(ctx)).to be_success
      end
    end

    context "when a cc_recipient for that party already exists on the document" do
      let(:members) do
        [ create(:distribution_list_member, distribution_list: distribution_list, party: internal_user, position: 1) ]
      end

      before { create(:cc_recipient, document: document, party: internal_user) }

      it "does not create a duplicate" do
        expect { described_class.execute(ctx) }.not_to change(document.cc_recipients, :count)
      end
    end

    context "with an empty list" do
      let(:members) { [] }

      it "creates no cc_recipients" do
        expect { described_class.execute(ctx) }.not_to change(document.cc_recipients, :count)
      end

      it "succeeds" do
        expect(described_class.execute(ctx)).to be_success
      end
    end
  end
end
