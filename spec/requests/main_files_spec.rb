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
        create(:entity_user, entity: entity, user: user, status: "active")
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
        create(:entity_user, entity: entity, user: user, status: "active")
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
end
