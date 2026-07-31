# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passkey management", type: :request do
  let(:user) { create(:user, password: "password123") }

  before do
    host! "webauthn.test"
    https!
    sign_in user
  end

  describe "GET /passkeys" do
    it "renders the management page" do
      get passkeys_path

      expect(response).to have_http_status(:ok)
    end

    it "renders with an existing passkey listed" do
      create_webauthn_credential_for(user, nickname: "My key")

      get passkeys_path

      expect(response.body).to include("My key")
    end
  end

  describe "GET /passkeys/options" do
    it "returns discoverable, user-verified creation options" do
      get options_passkeys_path

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["authenticatorSelection"]).to include(
        "residentKey" => "required",
        "userVerification" => "required"
      )
      expect(json["user"]["name"]).to eq(user.email)
    end

    it "excludes the user's already-registered credentials" do
      credential = create_webauthn_credential_for(user)

      get options_passkeys_path

      json = response.parsed_body
      excluded_ids = json["excludeCredentials"].map { |c| c["id"] }
      expect(excluded_ids).to include(credential.external_id)
    end
  end

  describe "POST /passkeys" do
    def register!(nickname: "My key")
      get options_passkeys_path
      options = response.parsed_body
      attestation = webauthn_fake_client.create(challenge: options["challenge"], user_verified: true)

      post passkeys_path, params: { credential: attestation, nickname: nickname }
    end

    it "creates a passkey and generates recovery codes on the user's first registration" do
      expect { register! }.to change { user.webauthn_credentials.count }.from(0).to(1)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["ok"]).to be true
      expect(json["backup_codes"]).to be_present
      expect(user.reload.otp_backup_codes).not_to be_empty
    end

    it "does not regenerate recovery codes on a second registration" do
      register!(nickname: "First key")
      first_codes = user.reload.otp_backup_codes

      register!(nickname: "Second key")

      json = response.parsed_body
      expect(json["backup_codes"]).to be_nil
      expect(user.reload.otp_backup_codes).to eq(first_codes)
    end

    it "rejects a blank nickname without creating a credential" do
      expect { register!(nickname: "  ") }.not_to(change { WebauthnCredential.count })

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /passkeys/:id" do
    it "restores password sign-in when the last passkey is removed for an optional-2FA user" do
      credential = create_webauthn_credential_for(user)

      delete passkey_path(credential)

      expect(user.reload.passwordless?).to be false
      expect(response).to redirect_to(passkeys_path)
    end

    it "redirects to two-factor setup when a mandatory-2FA user loses their last passkey with no TOTP configured" do
      entity = create(:entity)
      create(:entity_user, :owner, entity: entity, user: user)
      user.update!(otp_required_for_login: false, otp_secret: nil)
      credential = create_webauthn_credential_for(user)

      delete passkey_path(credential)

      expect(response).to redirect_to(two_factor_setup_path)
    end

    it "just removes the credential when other passkeys remain" do
      create_webauthn_credential_for(user, nickname: "Key 1")
      second = create_webauthn_credential_for(user, nickname: "Key 2")

      expect { delete passkey_path(second) }.to change { user.webauthn_credentials.count }.from(2).to(1)
      expect(user.reload.passwordless?).to be true
    end
  end
end
