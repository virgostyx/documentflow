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

    before { document.annexes.attach(io: StringIO.new("content"), filename: "appendix.pdf", content_type: "application/pdf") }

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
end
