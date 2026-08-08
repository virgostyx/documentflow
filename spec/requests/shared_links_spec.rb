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

      it "offers a way to request a new link" do
        get shared_document_path(token: shared_link.token)

        expect(response.body).to include(renew_shared_document_path(token: shared_link.token))
        expect(response.body).to include("Send me a new link")
      end

      context "when the document's shared link has already been renewed once" do
        before { document.update!(shared_link_renewed_at: 1.day.ago) }

        it "does not offer a way to request another new link" do
          get shared_document_path(token: shared_link.token)

          expect(response.body).not_to include("Send me a new link")
        end
      end
    end

    context "with an unknown token" do
      it "displays an unavailable message" do
        get shared_document_path(token: "unknown-token")

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("no longer available")
      end

      it "does not offer a way to request a new link" do
        get shared_document_path(token: "unknown-token")

        expect(response.body).not_to include("Send me a new link")
      end
    end
  end

  describe "POST /share/:token/renew (public, self-service renewal)" do
    let(:document) { create(:document, :finalized, entity: entity) }
    let!(:shared_link) { create(:shared_link, :expired, document: document) }

    context "with an email matching the document's external addressee" do
      it "enqueues an addressee notification" do
        expect(AddresseeNotificationJob).to receive(:perform_later)
          .with("Contact", document.addressee_id, document.id, document.created_by_id)

        post renew_shared_document_path(token: shared_link.token), params: { email: document.addressee.email }
      end

      it "displays a generic confirmation message" do
        post renew_shared_document_path(token: shared_link.token), params: { email: document.addressee.email }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("we&#39;ve sent a new link")
      end
    end

    context "with an email that does not match any external recipient" do
      it "does not enqueue any notification" do
        expect(AddresseeNotificationJob).not_to receive(:perform_later)
        expect(CcNotificationJob).not_to receive(:perform_later)

        post renew_shared_document_path(token: shared_link.token), params: { email: "nobody@example.com" }
      end

      it "displays the same generic confirmation message, without revealing the mismatch" do
        post renew_shared_document_path(token: shared_link.token), params: { email: "nobody@example.com" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("we&#39;ve sent a new link")
      end
    end

    context "with an unknown token" do
      it "displays the same generic confirmation message" do
        post renew_shared_document_path(token: "unknown-token"), params: { email: "nobody@example.com" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("we&#39;ve sent a new link")
      end
    end
  end

  describe "GET /share/:token/preview (public access)" do
    let(:document) { create(:document, :finalized, entity: entity) }
    let!(:shared_link) { create(:shared_link, document: document) }

    context "with a main document attached" do
      before { document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf") }

      it "renders the inline preview without requiring authentication" do
        get preview_shared_document_path(token: shared_link.token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(preview_content_shared_document_path(token: shared_link.token))
      end
    end

    context "when no main document is attached" do
      it "returns not found" do
        get preview_shared_document_path(token: shared_link.token)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an expired link" do
      let!(:shared_link) { create(:shared_link, :expired, document: document) }

      it "returns gone" do
        get preview_shared_document_path(token: shared_link.token)

        expect(response).to have_http_status(:gone)
      end
    end

    context "with an unknown token" do
      it "returns not found" do
        get preview_shared_document_path(token: "unknown-token")

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /share/:token/preview_content (public access)" do
    let(:document) { create(:document, :finalized, entity: entity) }
    let!(:shared_link) { create(:shared_link, document: document) }

    context "when the main file is already a PDF" do
      before { document.main_file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "main.pdf", content_type: "application/pdf") }

      it "streams the file inline without converting or requiring authentication" do
        expect(PdfConverter).not_to receive(:convert)

        get preview_content_shared_document_path(token: shared_link.token)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
        expect(response.headers["Content-Disposition"]).to include("inline")
      end
    end

    context "when no main document is attached" do
      it "returns not found" do
        get preview_content_shared_document_path(token: shared_link.token)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /share/:token/annexes/:id/preview (public access)" do
    let(:document) { create(:document, :finalized, entity: entity) }
    let!(:shared_link) { create(:shared_link, document: document) }
    let!(:annex) { create(:annex, document: document) }

    it "renders the inline preview without requiring authentication" do
      get preview_shared_document_annex_path(token: shared_link.token, id: annex.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(preview_content_shared_document_annex_path(token: shared_link.token, id: annex.id))
    end

    context "with an expired link" do
      let!(:shared_link) { create(:shared_link, :expired, document: document) }

      it "returns gone" do
        get preview_shared_document_annex_path(token: shared_link.token, id: annex.id)

        expect(response).to have_http_status(:gone)
      end
    end
  end

  describe "GET /share/:token/annexes/:id/preview_content (public access)" do
    let(:document) { create(:document, :finalized, entity: entity) }
    let!(:shared_link) { create(:shared_link, document: document) }
    let!(:annex) { create(:annex, document: document) }

    it "streams the file inline without requiring authentication" do
      get preview_content_shared_document_annex_path(token: shared_link.token, id: annex.id)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("inline")
    end
  end
end
