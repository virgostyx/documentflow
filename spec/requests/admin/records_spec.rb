# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin generic records browser", type: :request do
  let(:super_admin) do
    create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)
  end

  describe "model allowlist enforcement" do
    before { sign_in super_admin }

    %w[User SignatureImage AuditLog].each do |excluded_model|
      it "404s for #{excluded_model}, which is deliberately excluded from the registry" do
        get "/admin/records/#{excluded_model}"

        expect(response).to have_http_status(:not_found)
      end
    end

    it "succeeds for an allowlisted model" do
      department = create(:department, name: "Finance")

      get "/admin/records/Department"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Finance")
    end

    it "shows an allowlisted model's individual record" do
      department = create(:department, name: "Finance")

      get "/admin/records/Department/#{department.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Finance")
    end
  end

  describe "GET /admin/records/:model" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/admin/records/Department"

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular signed-in user" do
      before { sign_in create(:user) }

      it "redirects with an authorization alert" do
        get "/admin/records/Department"

        expect(response).to redirect_to("/")
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "column redaction" do
    before { sign_in super_admin }

    it "never renders a redacted column's raw value" do
      credential = create(:webauthn_credential, public_key: "super-secret-public-key-value")

      get "/admin/records/WebauthnCredential"
      expect(response.body).not_to include("super-secret-public-key-value")

      get "/admin/records/WebauthnCredential/#{credential.id}"
      expect(response.body).not_to include("super-secret-public-key-value")
      expect(response.body).to include("redacted")
    end
  end
end
