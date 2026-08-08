# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mission Control Jobs mount", type: :request do
  describe "GET /jobs" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/jobs"

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular signed-in user" do
      before { sign_in create(:user) }

      it "redirects with an authorization alert" do
        get "/jobs"

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "as a super admin" do
      let(:super_admin) do
        create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      end

      before { sign_in super_admin }

      it "renders the Mission Control Jobs dashboard" do
        get "/jobs"

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
