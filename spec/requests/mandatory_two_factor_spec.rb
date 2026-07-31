# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mandatory two-factor authentication", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }

  context "when the signed-in user is a plain member" do
    before do
      create(:entity_user, entity: entity, user: user)
      sign_in user
    end

    it "does not redirect to the two-factor setup page" do
      get dashboard_path

      expect(response).not_to redirect_to(two_factor_setup_path)
    end
  end

  context "when the signed-in user is an owner without two-factor configured" do
    before do
      create(:entity_user, :owner, entity: entity, user: user)
      # The factory pre-configures 2FA for owner/admin users as a convenience
      # for other specs; undo that here since this spec exercises the
      # not-yet-configured state itself.
      user.update!(otp_required_for_login: false, otp_secret: nil)
      login_as(user, scope: :user)
    end

    it "redirects every request to the two-factor setup page" do
      get dashboard_path

      expect(response).to redirect_to(two_factor_setup_path)
    end

    it "still allows reaching the two-factor setup page itself" do
      get two_factor_setup_path

      expect(response).to have_http_status(:ok)
    end

    it "still allows signing out" do
      delete destroy_user_session_path

      expect(response).to redirect_to(root_path)
    end
  end

  context "when the signed-in user is an owner with two-factor already configured" do
    before do
      create(:entity_user, :owner, entity: entity, user: user)
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      login_as(user, scope: :user)
    end

    it "does not redirect to the two-factor setup page" do
      get dashboard_path

      expect(response).not_to redirect_to(two_factor_setup_path)
    end
  end

  context "when the signed-in user is a super admin without two-factor configured" do
    before do
      login_as(create(:user, :super_admin), scope: :user)
    end

    it "redirects to the two-factor setup page" do
      get dashboard_path

      expect(response).to redirect_to(two_factor_setup_path)
    end
  end

  context "when the signed-in user is an owner with only a passkey (no TOTP)" do
    before do
      create(:entity_user, :owner, entity: entity, user: user)
      user.update!(otp_required_for_login: false, otp_secret: nil)
      create_webauthn_credential_for(user)
      login_as(user, scope: :user)
    end

    it "does not redirect to the two-factor setup page" do
      get dashboard_path

      expect(response).not_to redirect_to(two_factor_setup_path)
    end
  end
end
