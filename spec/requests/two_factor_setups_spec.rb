# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Two-factor setup", type: :request do
  let(:user) { create(:user, password: "password123") }

  before { sign_in user }

  describe "GET /two_factor_setup" do
    it "shows a QR code and secret to confirm when not yet enabled" do
      get two_factor_setup_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("svg")
    end

    it "keeps the same pending secret across repeated visits" do
      get two_factor_setup_path
      first_secret = session[:pending_otp_secret]

      get two_factor_setup_path

      expect(session[:pending_otp_secret]).to eq(first_secret)
    end

    it "shows the enabled state once configured" do
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)

      get two_factor_setup_path

      expect(response.body).to include("enabled")
    end

    it "redirects passwordless users to passkey management instead" do
      create_webauthn_credential_for(user)

      get two_factor_setup_path

      expect(response).to redirect_to(passkeys_path)
    end
  end

  describe "POST /two_factor_setup" do
    it "enables two-factor authentication with a valid code and shows backup codes once" do
      get two_factor_setup_path
      secret = session[:pending_otp_secret]

      post two_factor_setup_path, params: { otp_attempt: ROTP::TOTP.new(secret).now }

      expect(response).to have_http_status(:ok)
      expect(user.reload.otp_required_for_login).to be true
      expect(user.otp_secret).to eq(secret)
      expect(user.otp_backup_codes).not_to be_empty
    end

    it "rejects an invalid code and does not enable two-factor authentication" do
      get two_factor_setup_path

      post two_factor_setup_path, params: { otp_attempt: "000000" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.otp_required_for_login).to be false
    end
  end

  describe "POST /two_factor_setup/backup_codes" do
    it "regenerates backup codes, invalidating the previous ones" do
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      old_codes = user.generate_otp_backup_codes!
      user.save!

      post two_factor_setup_backup_codes_path

      expect(response).to have_http_status(:ok)
      new_hashes = user.reload.otp_backup_codes
      expect(new_hashes).not_to eq(old_codes)
    end

    it "refuses when two-factor authentication is not enabled yet" do
      post two_factor_setup_backup_codes_path

      expect(response).to redirect_to(two_factor_setup_path)
    end

    it "regenerates recovery codes for a passwordless user with no TOTP configured" do
      create_webauthn_credential_for(user)
      old_codes = user.reload.otp_backup_codes

      post two_factor_setup_backup_codes_path

      expect(response).to have_http_status(:ok)
      expect(user.reload.otp_backup_codes).not_to eq(old_codes)
    end
  end

  describe "DELETE /two_factor_setup" do
    context "when two-factor authentication is optional for the user" do
      before { user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret) }

      it "disables it with the correct current password" do
        delete two_factor_setup_path, params: { current_password: "password123" }

        expect(response).to redirect_to(two_factor_setup_path)
        expect(user.reload.otp_required_for_login).to be false
      end

      it "refuses with an incorrect current password" do
        delete two_factor_setup_path, params: { current_password: "wrong" }

        expect(user.reload.otp_required_for_login).to be true
      end
    end

    context "when two-factor authentication is mandatory for the user" do
      before do
        entity = create(:entity)
        create(:entity_user, :owner, entity: entity, user: user)
        user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      end

      it "refuses to disable it even with the correct password" do
        delete two_factor_setup_path, params: { current_password: "password123" }

        expect(user.reload.otp_required_for_login).to be true
      end

      it "allows disabling it when the user has also gone passwordless" do
        create_webauthn_credential_for(user)

        delete two_factor_setup_path, params: { current_password: "password123" }

        expect(user.reload.otp_required_for_login).to be false
      end
    end
  end
end
