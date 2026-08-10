# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MainFiles", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:file) { fixture_file_upload("sample.pdf", "application/pdf") }

  describe "POST /entities/:entity_id/documents/:document_id/main_file" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    context "as the document's author" do
      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "attaches the main document" do
        post entity_document_main_file_path(entity, document), params: { document: { main_file: file } }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.reload.main_file).to be_attached
      end

      it "replaces an existing main document" do
        document.main_file.attach(io: StringIO.new("old"), filename: "old.pdf", content_type: "application/pdf")

        post entity_document_main_file_path(entity, document), params: { document: { main_file: file } }

        document.reload
        expect(document.main_file.filename.to_s).to eq("sample.pdf")
      end

      it "rejects the request without a file" do
        post entity_document_main_file_path(entity, document), params: { document: {} }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
        expect(document.reload.main_file).not_to be_attached
      end
    end

    context "when the document is finalized" do
      let!(:document) { create(:document, :finalized, entity: entity, created_by: user) }

      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not attach the main document" do
        post entity_document_main_file_path(entity, document), params: { document: { main_file: file } }

        expect(response).to redirect_to(root_path)
        expect(document.reload.main_file).not_to be_attached
      end
    end

    context "as a guest who is not the document's author" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not attach the main document" do
        post entity_document_main_file_path(entity, document), params: { document: { main_file: file } }

        expect(response).to redirect_to(root_path)
        expect(document.reload.main_file).not_to be_attached
      end
    end

    context "when the document is checked out by another user" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
        document.update!(checked_out_by: create(:user), checked_out_at: Time.current)
      end

      it "does not attach the main document" do
        post entity_document_main_file_path(entity, document), params: { document: { main_file: file } }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
        expect(document.reload.main_file).not_to be_attached
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:document_id/main_file" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    before { document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf") }

    context "as the document's author" do
      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "removes the main document" do
        delete entity_document_main_file_path(entity, document)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.reload.main_file).not_to be_attached
      end
    end

    context "as a guest who is not the document's author" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not remove the main document" do
        delete entity_document_main_file_path(entity, document)

        expect(response).to redirect_to(root_path)
        expect(document.reload.main_file).to be_attached
      end
    end

    context "when the document is checked out by another user" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
        document.update!(checked_out_by: create(:user), checked_out_at: Time.current)
      end

      it "does not remove the main document" do
        delete entity_document_main_file_path(entity, document)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
        expect(document.reload.main_file).to be_attached
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/main_file/preview" do
    context "as a user who can view the document" do
      let!(:document) { create(:document, entity: entity, created_by: user) }

      before do
        document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf")
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "renders the inline preview" do
        get preview_entity_document_main_file_path(entity, document)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(preview_content_entity_document_main_file_path(entity, document))
        expect(response.body).to include('data-modal-target="previewLoader"')
        expect(response.body).to include('data-action="load->modal#hidePreviewLoader"')
      end
    end

    context "as a guest who cannot view the document" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf")
        sign_in user
      end

      it "denies access" do
        get preview_entity_document_main_file_path(entity, document)

        expect(response).to redirect_to(root_path)
      end
    end

    context "when no main document is attached" do
      let!(:document) { create(:document, entity: entity, created_by: user) }

      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "returns not found" do
        get preview_entity_document_main_file_path(entity, document)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/main_file/preview_content" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    before do
      create(:entity_user, :owner, entity: entity, user: user, status: "active")
      sign_in user
    end

    context "when the main file is already a PDF" do
      before { document.main_file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "main.pdf", content_type: "application/pdf") }

      it "streams the file inline without converting" do
        expect(PdfConverter).not_to receive(:convert)

        get preview_content_entity_document_main_file_path(entity, document)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
        expect(response.headers["Content-Disposition"]).to include("inline")
      end
    end

    context "when the main file is not a PDF" do
      before { document.main_file.attach(io: StringIO.new("plain text"), filename: "notes.txt", content_type: "text/plain") }

      it "converts it and streams the resulting PDF inline" do
        converted_path = Rails.root.join("tmp", "notes-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(converted_path, "%PDF-1.4 converted content")
        allow(PdfConverter).to receive(:convert).and_return(converted_path)

        get preview_content_entity_document_main_file_path(entity, document)

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq("%PDF-1.4 converted content")
      end

      it "returns unprocessable_content when the format cannot be converted" do
        allow(PdfConverter).to receive(:convert).and_raise(PdfConverter::ConversionError)

        get preview_content_entity_document_main_file_path(entity, document)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when no main document is attached" do
      it "returns not found" do
        get preview_content_entity_document_main_file_path(entity, document)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
