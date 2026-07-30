# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wopi::Files", type: :request do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity) }
  let(:visa_actor) { document.workflow_steps.find_by(role: "VISA").actor }
  let(:token) { Wopi::AccessToken.encode(document: document, user: visa_actor) }

  before do
    create(:entity_user, entity: entity, user: visa_actor, status: "active")
    document.workflow_steps.find_by(role: "RED").update!(status: "approved")
  end

  describe "GET /wopi/files/:id (CheckFileInfo)" do
    it "returns the document metadata when authorized" do
      get wopi_file_path(document), params: { access_token: token }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["BaseFileName"]).to eq(document.main_file.filename.to_s)
      expect(body["UserId"]).to eq(visa_actor.id.to_s)
      expect(body["UserCanWrite"]).to be true
    end

    it "returns 401 for an invalid token" do
      get wopi_file_path(document), params: { access_token: "garbage" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a user who is not the current step actor" do
      outsider = create(:user).tap { |u| create(:entity_user, entity: entity, user: u, status: "active") }
      outsider_token = Wopi::AccessToken.encode(document: document, user: outsider)

      get wopi_file_path(document), params: { access_token: outsider_token }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 once the document is frozen" do
      document.update!(is_frozen: true)

      get wopi_file_path(document), params: { access_token: token }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /wopi/files/:id/contents (GetFile)" do
    it "streams the current main_file bytes" do
      get wopi_file_contents_path(document), params: { access_token: token }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(document.main_file.download)
    end
  end

  describe "POST /wopi/files/:id (Lock/Unlock/RefreshLock)" do
    it "locks the document and stamps the WOPI lock id" do
      post wopi_file_path(document), params: { access_token: token },
        headers: { "X-WOPI-Override" => "LOCK", "X-WOPI-Lock" => "session-1" }

      expect(response).to have_http_status(:ok)
      document.reload
      expect(document.checked_out_by).to eq(visa_actor)
      expect(document.wopi_lock_id).to eq("session-1")
    end

    it "returns 409 with the existing lock when already checked out by someone else" do
      other = create(:user).tap { |u| create(:entity_user, entity: entity, user: u, status: "active") }
      document.update!(checked_out_by: other, checked_out_at: Time.current, wopi_lock_id: "other-session")

      post wopi_file_path(document), params: { access_token: token },
        headers: { "X-WOPI-Override" => "LOCK", "X-WOPI-Lock" => "session-1" }

      expect(response).to have_http_status(:conflict)
      expect(response.headers["X-WOPI-Lock"]).to eq("other-session")
    end

    it "refreshes the lock when the lock id matches" do
      document.update!(checked_out_by: visa_actor, checked_out_at: 1.hour.ago, wopi_lock_id: "session-1")

      expect {
        post wopi_file_path(document), params: { access_token: token },
          headers: { "X-WOPI-Override" => "REFRESH_LOCK", "X-WOPI-Lock" => "session-1" }
      }.to change { document.reload.checked_out_at }

      expect(response).to have_http_status(:ok)
    end

    it "rejects a refresh with a mismatched lock id" do
      document.update!(checked_out_by: visa_actor, checked_out_at: 1.hour.ago, wopi_lock_id: "session-1")

      post wopi_file_path(document), params: { access_token: token },
        headers: { "X-WOPI-Override" => "REFRESH_LOCK", "X-WOPI-Lock" => "wrong-session" }

      expect(response).to have_http_status(:conflict)
    end

    it "unlocks and releases the checkout" do
      document.update!(checked_out_by: visa_actor, checked_out_at: Time.current, wopi_lock_id: "session-1")

      post wopi_file_path(document), params: { access_token: token },
        headers: { "X-WOPI-Override" => "UNLOCK", "X-WOPI-Lock" => "session-1" }

      expect(response).to have_http_status(:ok)
      document.reload
      expect(document.checked_out_by).to be_nil
      expect(document.wopi_lock_id).to be_nil
    end
  end

  describe "POST /wopi/files/:id/contents (PutFile)" do
    let(:new_content) { "updated content" }

    before { document.update!(checked_out_by: visa_actor, checked_out_at: Time.current, wopi_lock_id: "session-1") }

    it "checks in a new version but keeps the document checked out (autosave)" do
      expect {
        post "#{wopi_file_contents_path(document)}?access_token=#{token}", params: new_content,
          headers: { "X-WOPI-Lock" => "session-1", "CONTENT_TYPE" => "application/octet-stream" }
      }.to change(DocumentFileVersion, :count).by(1)

      expect(response).to have_http_status(:ok)
      document.reload
      expect(document.checked_out_by).to eq(visa_actor)
      expect(document.wopi_lock_id).to eq("session-1")
      expect(document.main_file.download).to eq(new_content)
    end

    it "returns 409 when the lock id does not match" do
      post "#{wopi_file_contents_path(document)}?access_token=#{token}", params: new_content,
        headers: { "X-WOPI-Lock" => "wrong-session", "CONTENT_TYPE" => "application/octet-stream" }

      expect(response).to have_http_status(:conflict)
    end
  end
end
