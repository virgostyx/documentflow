# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Two-factor login challenge", type: :request do
  let(:secret) { User.generate_otp_secret }
  let(:user) do
    create(:user, password: "password123", otp_required_for_login: true, otp_secret: secret)
  end

  describe "POST /users/sign_in" do
    it "does not sign the user in directly, and stashes them pending the OTP challenge" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect(response).to redirect_to(new_two_factor_authentication_path)
      expect(controller.current_user).to be_nil
    end

    it "rejects an incorrect password before ever reaching the OTP step" do
      post user_session_path, params: { user: { email: user.email, password: "wrong" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Invalid email or password")
    end
  end

  describe "GET /two_factor_authentication/new" do
    it "redirects to sign in when there is no pending login" do
      get new_two_factor_authentication_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the challenge once a password has been verified" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      get new_two_factor_authentication_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /two_factor_authentication" do
    before do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
    end

    it "signs the user in with a valid TOTP code" do
      post two_factor_authentication_path, params: { otp_attempt: ROTP::TOTP.new(secret).now }

      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to eq(user)
    end

    it "signs the user in with a valid backup code" do
      codes = user.generate_otp_backup_codes!
      user.save!

      post two_factor_authentication_path, params: { otp_attempt: codes.first }

      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to eq(user)
    end

    it "consumes the backup code so it cannot be reused" do
      codes = user.generate_otp_backup_codes!
      user.save!

      post two_factor_authentication_path, params: { otp_attempt: codes.first }
      delete destroy_user_session_path

      # Re-verify the password to get a fresh pending login, then try to
      # replay the same (already-consumed) backup code.
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      post two_factor_authentication_path, params: { otp_attempt: codes.first }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an invalid code" do
      post two_factor_authentication_path, params: { otp_attempt: "000000" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(controller.current_user).to be_nil
    end

    it "clears the pending login once consumed, refusing a replay" do
      post two_factor_authentication_path, params: { otp_attempt: ROTP::TOTP.new(secret).now }
      delete destroy_user_session_path

      get new_two_factor_authentication_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
