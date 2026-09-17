# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Documents#dismiss", type: :request do
  let(:entity) { create(:entity) }
  let(:creator) { create(:user) }

  before { create(:entity_user, entity: entity, user: creator, status: "active") }

  describe "GET /entities/:entity_id/documents/:id/confirm_dismiss_waiting" do
    let(:document) { create(:document, :expecting_response, :finalized, entity: entity, created_by: creator) }

    it "renders successfully for the document's author" do
      sign_in creator

      get confirm_dismiss_waiting_entity_document_path(entity, document)

      expect(response).to have_http_status(:ok)
    end

    it "is forbidden for an unrelated member" do
      other = create(:user)
      create(:entity_user, entity: entity, user: other, role: "member", status: "active")
      sign_in other

      get confirm_dismiss_waiting_entity_document_path(entity, document)

      expect(response).to redirect_to(root_path)
    end

    it "offers incoming documents of the entity as a reply-link picker" do
      incoming = create(:document, :incoming, entity: entity, subject: "Original request")
      sign_in creator

      get confirm_dismiss_waiting_entity_document_path(entity, document)

      expect(response.body).to include(incoming.display_number)
    end

    it "does not offer the picker when the document already has a reply link" do
      incoming = create(:document, :incoming, entity: entity, subject: "Original request")
      document.update!(in_reply_to: incoming)
      sign_in creator

      get confirm_dismiss_waiting_entity_document_path(entity, document)

      expect(response.body).not_to include("in_reply_to_id")
    end
  end

  describe "POST /entities/:entity_id/documents/:id/dismiss_waiting" do
    let(:document) { create(:document, :expecting_response, :finalized, entity: entity, created_by: creator) }

    before { sign_in creator }

    it "records the dismissal with an optional message and redirects to the waiting list" do
      post dismiss_waiting_entity_document_path(entity, document), params: { message: "Handled offline" }

      dismissal = document.document_dismissals.find_by(user: creator, tab: "waiting")
      expect(dismissal.message).to eq("Handled offline")
      expect(response).to redirect_to(waiting_entity_documents_path(entity))
    end

    it "records the dismissal without a message" do
      post dismiss_waiting_entity_document_path(entity, document)

      dismissal = document.document_dismissals.find_by(user: creator, tab: "waiting")
      expect(dismissal).to be_present
      expect(dismissal.message).to be_nil
    end

    it "is idempotent on a repeat submission" do
      post dismiss_waiting_entity_document_path(entity, document)

      expect { post dismiss_waiting_entity_document_path(entity, document) }
        .not_to change { document.document_dismissals.count }
    end

    it "links the document to the chosen incoming mail" do
      incoming = create(:document, :incoming, entity: entity)

      post dismiss_waiting_entity_document_path(entity, document), params: { in_reply_to_id: incoming.id }

      expect(document.reload.in_reply_to_id).to eq(incoming.id)
    end

    it "ignores the reply link when the document is already linked" do
      original = create(:document, :incoming, entity: entity)
      document.update!(in_reply_to: original)
      other_incoming = create(:document, :incoming, entity: entity)

      post dismiss_waiting_entity_document_path(entity, document), params: { in_reply_to_id: other_incoming.id }

      expect(document.reload.in_reply_to_id).to eq(original.id)
    end

    it "ignores a reply link targeting a document outside the entity" do
      other_entity = create(:entity)
      outsider_incoming = create(:document, :incoming, entity: other_entity)

      post dismiss_waiting_entity_document_path(entity, document), params: { in_reply_to_id: outsider_incoming.id }

      expect(document.reload.in_reply_to_id).to be_nil
    end

    it "ignores a reply link targeting a non-incoming document" do
      outgoing = create(:document, :finalized, entity: entity)

      post dismiss_waiting_entity_document_path(entity, document), params: { in_reply_to_id: outgoing.id }

      expect(document.reload.in_reply_to_id).to be_nil
    end
  end

  describe "POST /entities/:entity_id/documents/:id/dismiss_info" do
    let(:document) { create(:document, :finalized, entity: entity, created_by: creator) }

    before { sign_in creator }

    it "records the dismissal and redirects to the info list" do
      post dismiss_info_entity_document_path(entity, document)

      expect(document.document_dismissals.find_by(user: creator, tab: "info")).to be_present
      expect(response).to redirect_to(info_entity_documents_path(entity))
    end

    it "is forbidden for an unrelated member" do
      other = create(:user)
      create(:entity_user, entity: entity, user: other, role: "member", status: "active")
      sign_out creator
      sign_in other

      post dismiss_info_entity_document_path(entity, document)

      expect(response).to redirect_to(root_path)
    end
  end
end
