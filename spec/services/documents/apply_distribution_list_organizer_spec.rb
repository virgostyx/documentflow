# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::ApplyDistributionListOrganizer do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:document) { create(:document, entity: entity, created_by: user) }
  let(:distribution_list) { create(:distribution_list, user: user) }

  describe ".call" do
    context "when all members belong to the document's entity" do
      let(:member1_party) { create(:contact, entity: entity) }
      let(:member2_party) { create(:user) }
      let(:member3_party) { create(:contact, entity: entity) }

      before do
        create(:entity_user, entity: entity, user: member2_party, status: "active")
        create(:distribution_list_member, distribution_list: distribution_list, party: member1_party, position: 1)
        create(:distribution_list_member, distribution_list: distribution_list, party: member2_party, position: 2,
               dispatch_as_attachment: true)
        create(:distribution_list_member, distribution_list: distribution_list, party: member3_party, position: 3)
      end

      it "sets the first member as addressee" do
        described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(document.reload.addressee).to eq(member1_party)
      end

      it "adds the remaining members as cc_recipients" do
        described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(document.cc_recipients.reload.map(&:party)).to contain_exactly(member2_party, member3_party)
      end

      it "carries over each member's dispatch_as_attachment default" do
        described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        cc = document.cc_recipients.reload.find_by(party: member2_party)
        expect(cc.dispatch_as_attachment).to be true
      end

      it "succeeds with no skipped members" do
        result = described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(result).to be_success
        expect(result.skipped_count).to eq(0)
      end

      it "records an audit log" do
        expect {
          described_class.call(document: document, distribution_list: distribution_list, current_user: user)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "when some members belong to a different entity" do
      let(:primary_party) { create(:contact, entity: entity) }
      let(:outsider_party) { create(:contact, entity: create(:entity)) }

      before do
        create(:distribution_list_member, distribution_list: distribution_list, party: primary_party, position: 1)
        create(:distribution_list_member, distribution_list: distribution_list, party: outsider_party, position: 2)
      end

      it "applies only the valid members and reports the skipped count" do
        result = described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(result).to be_success
        expect(result.skipped_count).to eq(1)
        expect(document.reload.addressee).to eq(primary_party)
        expect(document.cc_recipients.reload).to be_empty
      end
    end

    context "when no members belong to the document's entity" do
      let(:outsider_party) { create(:contact, entity: create(:entity)) }
      let(:original_addressee) { document.addressee }

      before do
        create(:distribution_list_member, distribution_list: distribution_list, party: outsider_party, position: 1)
      end

      it "fails and does not change the document" do
        result = described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(result).not_to be_success
        expect(document.reload.addressee).to eq(original_addressee)
      end
    end

    context "when the list has no members" do
      let(:original_addressee) { document.addressee }

      it "fails and does not change the document" do
        result = described_class.call(document: document, distribution_list: distribution_list, current_user: user)

        expect(result).not_to be_success
        expect(document.reload.addressee).to eq(original_addressee)
      end
    end
  end
end
