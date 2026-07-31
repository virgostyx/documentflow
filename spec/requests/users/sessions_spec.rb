# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Password sign-in", type: :request do
  let(:user) { create(:user, password: "password123") }

  describe "GET /users/sign_in" do
    it "offers passkey sign-in alongside the password form" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in with a passkey")
    end
  end

  describe "POST /users/sign_in" do
    it "signs in a regular (non-passwordless) user with the correct password" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect(response).to redirect_to(root_path)
    end

    it "rejects a passwordless account's password even when it is correct" do
      create_webauthn_credential_for(user)

      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("passkey")

      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
