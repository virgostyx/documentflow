# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SharedLinks", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }

  describe "POST /entities/:entity_id/documents/:document_id/shared_links" do
    context "when the document is finalized" do
      let!(:document) { create(:document, :finalized, entity: entity) }

      context "as an entity member" do
        before do
          create(:entity_user, entity: entity, user: user)
          sign_in user
        end

        it "creates a share link" do
          expect {
            post entity_document_shared_links_path(entity, document)
          }.to change(document.shared_links, :count).by(1)
        end

        it "redirects to the document page" do
          post entity_document_shared_links_path(entity, document)

          expect(response).to redirect_to(entity_document_path(entity, document))
          expect(flash[:notice]).to be_present
        end
      end

      context "as a guest" do
        before do
          create(:entity_user, :guest, entity: entity, user: user)
          sign_in user
        end

        it "does not create a share link" do
          expect {
            post entity_document_shared_links_path(entity, document)
          }.not_to change(SharedLink, :count)

          expect(response).to redirect_to(root_path)
        end
      end
    end

    context "when the document is not finalized" do
      let!(:document) { create(:document, :in_progress, entity: entity) }

      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "does not create a share link" do
        expect {
          post entity_document_shared_links_path(entity, document)
        }.not_to change(SharedLink, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:document_id/shared_links/:id" do
    let!(:document) { create(:document, :finalized, entity: entity) }
    let!(:shared_link) { create(:shared_link, document: document) }

    context "as an entity member" do
      before do
        create(:entity_user, entity: entity, user: user)
        sign_in user
      end

      it "revokes the share link" do
        expect {
          delete entity_document_shared_link_path(entity, document, shared_link)
        }.to change(document.shared_links, :count).by(-1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "as a guest" do
      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "does not revoke the share link" do
        expect {
          delete entity_document_shared_link_path(entity, document, shared_link)
        }.not_to change(SharedLink, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /share/:token (public access)" do
    context "with a valid, active link to a finalized document" do
      let(:document) { create(:document, :finalized, entity: entity, subject: "Supplier agreement") }
      let!(:shared_link) { create(:shared_link, document: document) }

      it "displays the document without requiring authentication" do
        get shared_document_path(token: shared_link.token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document.subject)
        expect(response.body).to include(document.reference_number)
      end
    end

    context "with an expired link" do
      let(:document) { create(:document, :finalized, entity: entity) }
      let!(:shared_link) { create(:shared_link, :expired, document: document) }

      it "displays an unavailable message" do
        get shared_document_path(token: shared_link.token)

        expect(response).to have_http_status(:gone)
        expect(response.body).to include("no longer available")
      end
    end

    context "with an unknown token" do
      it "displays an unavailable message" do
        get shared_document_path(token: "unknown-token")

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("no longer available")
      end
    end
  end
end
