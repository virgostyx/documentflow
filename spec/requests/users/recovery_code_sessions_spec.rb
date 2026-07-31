# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recovery code sign-in", type: :request do
  let(:user) { create(:user, password: "password123") }

  describe "GET /recovery_code_session/new" do
    it "renders the recovery code form" do
      get new_recovery_code_session_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /recovery_code_session" do
    it "signs in a passwordless user with a valid, unconsumed code and consumes it" do
      create_webauthn_credential_for(user)
      codes = user.generate_otp_backup_codes!
      user.save!

      post recovery_code_session_path, params: { email: user.email, recovery_code: codes.first }

      expect(response).to redirect_to(passkeys_path)
      get dashboard_path
      expect(response).not_to redirect_to(new_user_session_path)

      # Same code cannot be reused.
      delete destroy_user_session_path
      post recovery_code_session_path, params: { email: user.email, recovery_code: codes.first }
      expect(flash[:alert]).to be_present
    end

    it "rejects a backup code for a non-passwordless (TOTP-only) user" do
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      codes = user.generate_otp_backup_codes!
      user.save!

      post recovery_code_session_path, params: { email: user.email, recovery_code: codes.first }

      expect(response).to have_http_status(:unprocessable_content)
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "rejects an invalid code" do
      create_webauthn_credential_for(user)
      user.generate_otp_backup_codes!
      user.save!

      post recovery_code_session_path, params: { email: user.email, recovery_code: "not-a-real-code" }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
