# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SIGN step-up challenges", type: :request do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity) }
  let(:sign_step) { document.workflow_steps.find_by(role: "SIGN") }
  let(:signer) { sign_step.actor }

  before do
    host! "webauthn.test"
    https!
    create(:entity_user, entity: entity, user: signer)
    document.workflow_steps.find_by(role: "RED")&.update!(status: "approved")
    document.workflow_steps.find_by(role: "VISA")&.update!(status: "approved")
    sign_in signer
  end

  describe "GET .../confirm_sign" do
    it "renders the confirmation modal for the step's actor" do
      get confirm_sign_entity_document_workflow_step_path(entity, document, sign_step)

      expect(response).to have_http_status(:ok)
    end

    it "denies access to another user" do
      other = create(:user)
      create(:entity_user, entity: entity, user: other)
      sign_in other

      get confirm_sign_entity_document_workflow_step_path(entity, document, sign_step)

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "GET .../step_up_options" do
    it "returns request options scoped to the current user's own credentials" do
      credential = create_webauthn_credential_for(signer)

      get step_up_options_entity_document_workflow_step_path(entity, document, sign_step)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["userVerification"]).to eq("required")
      expect(json["allowCredentials"].map { |c| c["id"] }).to eq([ credential.external_id ])
    end

    it "returns not found for a non-SIGN step" do
      visa_step = document.workflow_steps.find_by(role: "VISA")
      create(:entity_user, entity: entity, user: visa_step.actor) unless EntityUser.exists?(entity: entity, user: visa_step.actor)
      sign_in visa_step.actor

      get step_up_options_entity_document_workflow_step_path(entity, document, visa_step)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST .../step_up_verify" do
    def assertion_for(user, client: webauthn_fake_client, **options)
      get step_up_options_entity_document_workflow_step_path(entity, document, sign_step)
      challenge = response.parsed_body["challenge"]
      client.get(challenge: challenge, user_verified: true, user_handle: Base64.urlsafe_decode64(user.webauthn_id), **options)
    end

    it "verifies a valid assertion and mints a step-scoped token without signing in a new session" do
      credential = create_webauthn_credential_for(signer)

      assertion = assertion_for(signer)
      post step_up_verify_entity_document_workflow_step_path(entity, document, sign_step), params: { credential: assertion }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["ok"]).to be true
      expect(json["step_up_token"]).to be_present
      expect(session[:step_up_tokens][sign_step.id.to_s]["token"]).to eq(json["step_up_token"])

      expect(credential.reload.sign_count).to be > 0
      expect(credential.last_used_at).to be_present
    end

    it "rejects a credential belonging to another user" do
      create_webauthn_credential_for(signer)
      other_user = create(:user)
      create_webauthn_credential_for(other_user)

      assertion = assertion_for(other_user)
      post step_up_verify_entity_document_workflow_step_path(entity, document, sign_step), params: { credential: assertion }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a stale/replayed sign_count" do
      credential = create_webauthn_credential_for(signer)
      credential.update!(sign_count: 999_999)

      assertion = assertion_for(signer)
      post step_up_verify_entity_document_workflow_step_path(entity, document, sign_step), params: { credential: assertion }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
