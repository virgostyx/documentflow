# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Documents#apply_distribution_list", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:distribution_list) { create(:distribution_list, user: user) }
  let(:primary_party) { create(:contact, entity: entity) }
  let(:cc_party) { create(:contact, entity: entity) }

  describe "POST /entities/:entity_id/documents/:id/apply_distribution_list" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    before do
      create(:distribution_list_member, distribution_list: distribution_list, party: primary_party, position: 1)
      create(:distribution_list_member, distribution_list: distribution_list, party: cc_party, position: 2)
    end

    context "as the document's author, while it is still a draft" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "sets the addressee and adds the remaining members as cc_recipients" do
        post apply_distribution_list_entity_document_path(entity, document),
             params: { distribution_list_id: distribution_list.id }

        document.reload
        expect(document.addressee).to eq(primary_party)
        expect(document.cc_recipients.map(&:party)).to contain_exactly(cc_party)
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end

      it "does not apply a list owned by another user" do
        other_list = create(:distribution_list, user: create(:user))
        create(:distribution_list_member, distribution_list: other_list, party: primary_party, position: 1)

        post apply_distribution_list_entity_document_path(entity, document),
             params: { distribution_list_id: other_list.id }

        expect(document.reload.addressee).not_to eq(primary_party)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the document is in_progress" do
      let!(:document) do
        document = create(:document, :in_progress, entity: entity, created_by: user)
        create(:workflow_step, document: document, role: "VISA", order: 1, status: "pending", actor: user)
        document
      end
      let(:original_addressee) { document.addressee }

      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "is forbidden, even for the current step's actor" do
        post apply_distribution_list_entity_document_path(entity, document),
             params: { distribution_list_id: distribution_list.id }

        expect(response).to redirect_to(root_path)
        expect(document.reload.addressee).to eq(original_addressee)
      end
    end
  end
end
