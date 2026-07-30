# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DocumentCheckouts", type: :request do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity) }
  let(:visa_actor) { document.workflow_steps.find_by(role: "VISA").actor }
  let(:new_file) { fixture_file_upload("sample.pdf", "application/pdf") }

  before do
    create(:entity_user, entity: entity, user: visa_actor, status: "active")
    document.workflow_steps.find_by(role: "RED").update!(status: "approved")
  end

  describe "POST /entities/:entity_id/documents/:document_id/checkout" do
    context "as the current step actor" do
      before { sign_in visa_actor }

      it "checks out the document" do
        post entity_document_checkout_path(entity, document)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.reload.checked_out_by).to eq(visa_actor)
      end
    end

    context "as a user without update rights" do
      let(:outsider) { create(:user).tap { |u| create(:entity_user, :guest, entity: entity, user: u, status: "active") } }

      before { sign_in outsider }

      it "does not check out the document" do
        post entity_document_checkout_path(entity, document)

        expect(response).to redirect_to(root_path)
        expect(document.reload.checked_out_by).to be_nil
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/checkout/confirm_check_in" do
    before do
      document.update!(checked_out_by: visa_actor, checked_out_at: Time.current)
      sign_in visa_actor
    end

    it "renders the check-in form" do
      get confirm_check_in_entity_document_checkout_path(entity, document)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /entities/:entity_id/documents/:document_id/checkout" do
    before { document.update!(checked_out_by: visa_actor, checked_out_at: Time.current) }

    context "as the user who checked out the document" do
      before { sign_in visa_actor }

      it "checks in the new version and redirects" do
        patch entity_document_checkout_path(entity, document),
          params: { document_file_version: { file: new_file, comment: "Fixed typo" } }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.reload.checked_out_by).to be_nil
        expect(document.document_file_versions.count).to eq(1)
      end
    end

    context "as a different user" do
      let(:other_user) { create(:user).tap { |u| create(:entity_user, entity: entity, user: u, status: "active") } }

      before { sign_in other_user }

      it "does not check in and does not change the lock" do
        patch entity_document_checkout_path(entity, document),
          params: { document_file_version: { file: new_file } }

        expect(response).to redirect_to(root_path)
        expect(document.reload.checked_out_by).to eq(visa_actor)
      end
    end

    context "checking in only an annex, with no main file" do
      let!(:annex) { create(:annex, document: document) }

      before { sign_in visa_actor }

      it "checks in the annex and releases the lock" do
        patch entity_document_checkout_path(entity, document),
          params: { annex_versions: { annex.id.to_s => new_file } }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.reload.checked_out_by).to be_nil
        expect(annex.reload.file.filename.to_s).to eq("sample.pdf")
      end
    end

    context "checking in both the main file and an annex" do
      let!(:annex) { create(:annex, document: document) }

      before { sign_in visa_actor }

      it "checks in both files in one submission" do
        patch entity_document_checkout_path(entity, document),
          params: {
            document_file_version: { file: new_file, comment: "Both updated" },
            annex_versions: { annex.id.to_s => new_file }
          }

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(document.document_file_versions.count).to eq(2)
        expect(document.document_file_versions.pluck(:version_number).uniq).to eq([ 1 ])
      end
    end

    context "checking in without selecting any file" do
      before { sign_in visa_actor }

      it "fails, keeps the checkout, and does not create a version" do
        patch entity_document_checkout_path(entity, document), params: {}

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
        expect(document.reload.checked_out_by).to eq(visa_actor)
        expect(document.document_file_versions.count).to eq(0)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/checkout/edit_online" do
    before do
      document.update!(checked_out_by: visa_actor, checked_out_at: Time.current)
      sign_in visa_actor
    end

    it "renders the online editor when Collabora is reachable" do
      allow(Wopi::EditUrl).to receive(:for).and_return("https://office.example.com/browser/1234/cool.html?WOPISrc=x")

      get edit_online_entity_document_checkout_path(entity, document)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://office.example.com/browser/1234/cool.html?WOPISrc=x")
    end

    it "falls back gracefully when Collabora is unreachable" do
      allow(Wopi::EditUrl).to receive(:for).and_raise(SocketError, "getaddrinfo failed")

      get edit_online_entity_document_checkout_path(entity, document)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Online editor unavailable")
    end

    it "is not accessible to a user who has not checked out the document" do
      other_user = create(:user).tap { |u| create(:entity_user, entity: entity, user: u, status: "active") }
      sign_in other_user

      get edit_online_entity_document_checkout_path(entity, document)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/checkout/confirm_cancel" do
    before do
      document.update!(checked_out_by: visa_actor, checked_out_at: Time.current)
      sign_in visa_actor
    end

    it "renders the cancel confirmation" do
      get confirm_cancel_entity_document_checkout_path(entity, document)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /entities/:entity_id/documents/:document_id/checkout" do
    before { document.update!(checked_out_by: visa_actor, checked_out_at: Time.current) }

    context "as the user who checked out the document" do
      before { sign_in visa_actor }

      it "releases the checkout without creating a version" do
        delete entity_document_checkout_path(entity, document)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.reload.checked_out_by).to be_nil
        expect(document.document_file_versions.count).to eq(0)
      end
    end

    context "as an unrelated member" do
      let(:other_member) { create(:user).tap { |u| create(:entity_user, entity: entity, user: u, role: "member", status: "active") } }

      before { sign_in other_member }

      it "does not release the checkout" do
        delete entity_document_checkout_path(entity, document)

        expect(response).to redirect_to(root_path)
        expect(document.reload.checked_out_by).to eq(visa_actor)
      end
    end
  end
end
