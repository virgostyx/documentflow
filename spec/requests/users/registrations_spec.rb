# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profile updates", type: :request do
  let(:user) { create(:user, password: "password123", first_name: "Jean") }

  before { sign_in user }

  describe "GET /users/edit" do
    it "shows the change-password fields for a regular user" do
      get edit_user_registration_path

      expect(response.body).to include("Change password")
      expect(response.body).to include("Manage passkeys")
    end

    it "hides the change-password fields for a passwordless user" do
      create_webauthn_credential_for(user)

      get edit_user_registration_path

      expect(response.body).not_to include("Change password")
      expect(response.body).to include("Not needed")
    end
  end

  describe "PUT /users" do
    it "requires the current password for a regular (non-passwordless) user" do
      put user_registration_path, params: { user: { first_name: "Jean-Paul" } }

      expect(user.reload.first_name).to eq("Jean")
    end

    it "updates without a current password for a passwordless user" do
      create_webauthn_credential_for(user)

      put user_registration_path, params: { user: { first_name: "Jean-Paul" } }

      expect(user.reload.first_name).to eq("Jean-Paul")
    end
  end
end
