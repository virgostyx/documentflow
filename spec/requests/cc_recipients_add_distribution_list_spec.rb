# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CcRecipients#add_distribution_list", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:distribution_list) { create(:distribution_list, user: user) }
  let(:member_a) { create(:contact, entity: entity) }
  let(:member_b) { create(:contact, entity: entity) }

  describe "POST /entities/:entity_id/documents/:document_id/cc_recipients/add_distribution_list" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    before do
      create(:distribution_list_member, distribution_list: distribution_list, party: member_a, position: 1)
      create(:distribution_list_member, distribution_list: distribution_list, party: member_b, position: 2)
    end

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "adds every list member as a cc_recipient without touching the addressee" do
        original_addressee = document.addressee

        expect {
          post add_distribution_list_entity_document_cc_recipients_path(entity, document),
               params: { distribution_list_id: distribution_list.id }
        }.to change(document.cc_recipients, :count).by(2)

        expect(document.reload.addressee).to eq(original_addressee)
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "when the document is finalized" do
      let!(:document) { create(:document, :finalized, entity: entity, created_by: user) }

      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not add recipients" do
        expect {
          post add_distribution_list_entity_document_cc_recipients_path(entity, document),
               params: { distribution_list_id: distribution_list.id }
        }.not_to change(document.cc_recipients, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
