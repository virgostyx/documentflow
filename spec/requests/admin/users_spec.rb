# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:super_admin) do
    create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)
  end

  describe "GET /admin/users" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/admin/users"

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular signed-in user" do
      before { sign_in create(:user) }

      it "redirects with an authorization alert" do
        get "/admin/users"

        expect(response).to redirect_to("/")
        expect(flash[:alert]).to be_present
      end
    end

    context "as a super admin" do
      before { sign_in super_admin }

      it "lists users" do
        other_user = create(:user, first_name: "Ada", last_name: "Lovelace")

        get "/admin/users"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ada Lovelace")
        expect(response.body).to include(other_user.email)
      end
    end
  end

  describe "GET /admin/users/:id" do
    before { sign_in super_admin }

    it "shows curated fields only, never Devise/2FA secrets" do
      user = create(:user, first_name: "Ada", last_name: "Lovelace")

      get "/admin/users/#{user.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ada Lovelace")
      expect(response.body).to include(user.email)
      expect(response.body).not_to include(user.encrypted_password)
      expect(response.body).not_to include(user.reset_password_token.to_s) if user.reset_password_token.present?
    end
  end

  describe "GET /admin/users/:id/confirm_revoke_super_admin" do
    before { sign_in super_admin }

    it "renders the confirmation inside the modal frame" do
      target = create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)

      get "/admin/users/#{target.id}/confirm_revoke_super_admin"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-frame id="modal"')
    end
  end

  describe "PATCH /admin/users/:id/grant_super_admin" do
    before { sign_in super_admin }

    it "grants super_admin to the target user" do
      target = create(:user, super_admin: false)

      patch "/admin/users/#{target.id}/grant_super_admin"

      expect(target.reload.super_admin?).to be true
      expect(response).to redirect_to(admin_user_path(target))
    end
  end

  describe "PATCH /admin/users/:id/revoke_super_admin" do
    before { sign_in super_admin }

    it "revokes super_admin from the target user" do
      target = create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)

      patch "/admin/users/#{target.id}/revoke_super_admin"

      expect(target.reload.super_admin?).to be false
      expect(response).to redirect_to(admin_user_path(target))
    end

    it "allows revoking your own super_admin status" do
      patch "/admin/users/#{super_admin.id}/revoke_super_admin"

      expect(super_admin.reload.super_admin?).to be false
    end
  end
end
