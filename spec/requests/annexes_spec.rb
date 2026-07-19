# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Annexes", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:file) { fixture_file_upload("sample.pdf", "application/pdf") }

  describe "POST /entities/:entity_id/documents/:document_id/annexes" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "attaches an annex" do
        expect {
          post entity_document_annexes_path(entity, document), params: { document: { annex: file } }
        }.to change { document.reload.annexes.count }.by(1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end

      it "rejects the request without a file" do
        post entity_document_annexes_path(entity, document), params: { document: {} }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
        expect(document.reload.annexes).to be_empty
      end
    end

    context "when the document is finalized" do
      let!(:document) { create(:document, :finalized, entity: entity, created_by: user) }

      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not attach an annex" do
        expect {
          post entity_document_annexes_path(entity, document), params: { document: { annex: file } }
        }.not_to change { document.reload.annexes.count }

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest who is not the document's author" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not attach an annex" do
        expect {
          post entity_document_annexes_path(entity, document), params: { document: { annex: file } }
        }.not_to change { document.reload.annexes.count }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:document_id/annexes/:id" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    before { document.annexes.create!(file: { io: StringIO.new("content"), filename: "appendix.pdf", content_type: "application/pdf" }) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "removes the annex" do
        annex = document.annexes.first

        expect {
          delete entity_document_annex_path(entity, document, annex)
        }.to change { document.reload.annexes.count }.by(-1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "as a guest who is not the document's author" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not remove the annex" do
        annex = document.annexes.first

        expect {
          delete entity_document_annex_path(entity, document, annex)
        }.not_to change { document.reload.annexes.count }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/annexes/:id/preview" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    before { document.annexes.create!(file: { io: StringIO.new("content"), filename: "appendix.pdf", content_type: "application/pdf" }) }

    context "as a user who can view the document" do
      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "renders the inline preview" do
        annex = document.annexes.first

        get preview_entity_document_annex_path(entity, document, annex)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(preview_content_entity_document_annex_path(entity, document, annex))
      end
    end

    context "as a guest who cannot view the document" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        document.annexes.create!(file: { io: StringIO.new("content"), filename: "appendix.pdf", content_type: "application/pdf" })
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "denies access" do
        annex = document.annexes.first

        get preview_entity_document_annex_path(entity, document, annex)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/annexes/:id/preview_content" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    before do
      create(:entity_user, :owner, entity: entity, user: user, status: "active")
      sign_in user
    end

    context "when the annex is already a PDF" do
      let!(:annex) { document.annexes.create!(file: { io: StringIO.new("%PDF-1.4 content"), filename: "appendix.pdf", content_type: "application/pdf" }) }

      it "streams the file inline without converting" do
        expect(PdfConverter).not_to receive(:convert)

        get preview_content_entity_document_annex_path(entity, document, annex)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
      end
    end

    context "when the annex is not a PDF" do
      let!(:annex) { document.annexes.create!(file: { io: StringIO.new("plain text"), filename: "notes.txt", content_type: "text/plain" }) }

      it "converts it and streams the resulting PDF inline" do
        converted_path = Rails.root.join("tmp", "notes-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(converted_path, "%PDF-1.4 converted content")
        allow(PdfConverter).to receive(:convert).and_return(converted_path)

        get preview_content_entity_document_annex_path(entity, document, annex)

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq("%PDF-1.4 converted content")
      end

      it "returns unprocessable_content when the format cannot be converted" do
        allow(PdfConverter).to receive(:convert).and_raise(PdfConverter::ConversionError)

        get preview_content_entity_document_annex_path(entity, document, annex)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
