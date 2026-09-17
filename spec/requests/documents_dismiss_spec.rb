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
