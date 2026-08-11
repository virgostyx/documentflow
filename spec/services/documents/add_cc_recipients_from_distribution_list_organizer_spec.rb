# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::AddCcRecipientsFromDistributionListOrganizer do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:document) { create(:document, entity: entity, created_by: user) }
  let(:distribution_list) { create(:distribution_list, user: user) }
  let(:original_addressee) { document.addressee }

  describe ".call" do
    context "when all members belong to the document's entity" do
      let(:member1_party) { create(:contact, entity: entity) }
      let(:member2_party) { create(:contact, entity: entity) }

      before do
        create(:distribution_list_member, distribution_list: distribution_list, party: member1_party, position: 1)
        create(:distribution_list_member, distribution_list: distribution_list, party: member2_party, position: 2)
      end

      it "adds every member as a cc_recipient" do
        described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(document.cc_recipients.reload.map(&:party)).to contain_exactly(member1_party, member2_party)
      end

      it "does not change the addressee" do
        described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(document.reload.addressee).to eq(original_addressee)
      end

      it "succeeds" do
        result = described_class.call(document: document, distribution_list: distribution_list, current_user: user)
        expect(result).to be_success
      end

      it "records an audit log" do
        expect {
          described_class.call(document: document, distribution_list: distribution_list, current_user: user)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "when some members belong to a different entity" do
      let(:valid_party) { create(:contact, entity: entity) }
      let(:outsider_party) { create(:contact, entity: create(:entity)) }

      before do
        create(:distribution_list_member, distribution_list: distribution_list, party: valid_party, position: 1)
        create(:distribution_list_member, distribution_list: distribution_list, party: outsider_party, position: 2)
      end

      it "adds only the valid members and reports the skipped count" do
        result = described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(result).to be_success
        expect(result.skipped_count).to eq(1)
        expect(document.cc_recipients.reload.map(&:party)).to contain_exactly(valid_party)
      end
    end

    context "when the list has no members" do
      it "succeeds without adding any cc_recipients" do
        result = described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(result).to be_success
        expect(document.cc_recipients.reload).to be_empty
      end
    end
  end
end
