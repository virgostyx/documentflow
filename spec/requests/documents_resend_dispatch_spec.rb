# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Documents#resend_dispatch", type: :request do
  let(:entity) { create(:entity) }
  let(:creator) { create(:user) }
  let(:document) { create(:document, :finalized, entity: entity, created_by: creator) }

  describe "POST /entities/:entity_id/documents/:id/resend_dispatch" do
    context "as the document's creator" do
      before do
        create(:entity_user, entity: entity, user: creator, status: "active")
        sign_in creator
      end

      it "enqueues the addressee notification job and redirects with a notice" do
        expect(AddresseeNotificationJob).to receive(:perform_later)
          .with(document.addressee_type, document.addressee_id, document.id, creator.id)

        post resend_dispatch_entity_document_path(entity, document),
             params: { recipient_type: document.addressee_type, recipient_id: document.addressee_id }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end

      it "redirects with an alert when the recipient is unknown" do
        post resend_dispatch_entity_document_path(entity, document),
             params: { recipient_type: "Contact", recipient_id: -1 }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "as an unrelated entity member" do
      let(:member) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: member, role: "member", status: "active")
        sign_in member
      end

      it "is forbidden" do
        post resend_dispatch_entity_document_path(entity, document),
             params: { recipient_type: document.addressee_type, recipient_id: document.addressee_id }

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
