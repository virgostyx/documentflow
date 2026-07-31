# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Password reset", type: :request do
  let(:user) { create(:user, password: "password123") }

  describe "POST /users/password" do
    it "sends a reset email for a regular (non-passwordless) user" do
      expect {
        post user_password_path, params: { user: { email: user.email } }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "refuses to send a reset email for a passwordless account" do
      create_webauthn_credential_for(user)

      expect {
        post user_password_path, params: { user: { email: user.email } }
      }.not_to(change { ActionMailer::Base.deliveries.count })

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
