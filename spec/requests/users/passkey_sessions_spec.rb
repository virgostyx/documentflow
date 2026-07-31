# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passwordless passkey sign-in", type: :request do
  let(:user) { create(:user, password: "password123") }

  before do
    host! "webauthn.test"
    https!
  end

  describe "GET /passkey_session/options" do
    it "returns discoverable, user-verified request options with no allow list" do
      get passkey_session_options_path

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["userVerification"]).to eq("required")
      expect(json["allowCredentials"]).to eq([])
    end
  end

  describe "POST /passkey_session" do
    def assertion_for(user, **options)
      get passkey_session_options_path
      challenge = response.parsed_body["challenge"]
      webauthn_fake_client.get(challenge: challenge, user_verified: true, user_handle: Base64.urlsafe_decode64(user.webauthn_id), **options)
    end

    it "signs in directly with a valid assertion, bypassing any TOTP challenge" do
      entity = create(:entity)
      create(:entity_user, :owner, entity: entity, user: user)
      user.update!(otp_required_for_login: false, otp_secret: nil)
      credential = create_webauthn_credential_for(user)

      assertion = assertion_for(user)
      post passkey_session_path, params: { credential: assertion }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_to"]).to be_present
      expect(session[:otp_user_id]).to be_nil

      get dashboard_path
      expect(response).not_to redirect_to(new_user_session_path)

      expect(credential.reload.sign_count).to be > 0
      expect(credential.last_used_at).to be_present
    end

    it "rejects an assertion for an unknown credential" do
      create_webauthn_credential_for(user)
      other_user = create(:user, password: "password123")

      assertion = assertion_for(other_user)
      post passkey_session_path, params: { credential: assertion }

      expect(response).to have_http_status(:unprocessable_content)
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "rejects a stale/replayed sign_count and does not sign in" do
      credential = create_webauthn_credential_for(user)
      credential.update!(sign_count: 999_999)

      assertion = assertion_for(user)
      post passkey_session_path, params: { credential: assertion }

      expect(response).to have_http_status(:unprocessable_content)
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "rejects an assertion whose user handle does not match the credential owner" do
      create_webauthn_credential_for(user)
      impostor = create(:user)

      assertion = assertion_for(impostor)
      post passkey_session_path, params: { credential: assertion }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
