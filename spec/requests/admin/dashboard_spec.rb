# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  describe "GET /admin" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/admin"

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular signed-in user" do
      before { sign_in create(:user) }

      it "redirects with an authorization alert" do
        get "/admin"

        expect(response).to redirect_to("/")
        expect(flash[:alert]).to be_present
      end
    end

    context "as a super admin" do
      let(:super_admin) do
        create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      end

      before { sign_in super_admin }

      it "renders the admin dashboard" do
        get "/admin"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Admin")
      end

      it "links to every model in the read-only records browser" do
        get "/admin"

        expect(response.body).to include(admin_records_path(model: "Department"))
        expect(response.body).to include(admin_records_path(model: "SharedLink"))
      end
    end
  end
end
