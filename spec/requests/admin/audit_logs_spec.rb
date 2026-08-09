# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin audit logs", type: :request do
  let(:super_admin) do
    create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)
  end

  describe "GET /admin/audit_logs" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/admin/audit_logs"

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular signed-in user" do
      before { sign_in create(:user) }

      it "redirects with an authorization alert" do
        get "/admin/audit_logs"

        expect(response).to redirect_to("/")
        expect(flash[:alert]).to be_present
      end
    end

    context "as a super admin" do
      before { sign_in super_admin }

      it "lists audit logs" do
        log = create(:audit_log, action: "launch")

        get "/admin/audit_logs"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(log.user.email)
      end
    end
  end

  describe "GET /admin/audit_logs/:id" do
    before { sign_in super_admin }

    it "shows the audit log" do
      log = create(:audit_log, action: "launch", change_data: { "steps_added" => 3 })

      get "/admin/audit_logs/#{log.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(log.user.email)
    end

    it "falls back to a humanized action for unmapped actions" do
      log = create(:audit_log, action: "some_unmapped_action")

      get "/admin/audit_logs/#{log.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Some unmapped action")
    end
  end

  it "has no update or destroy route, matching AuditLog's append-only invariant" do
    expect do
      Rails.application.routes.recognize_path("/admin/audit_logs/1", method: :patch)
    end.to raise_error(ActionController::RoutingError)

    expect do
      Rails.application.routes.recognize_path("/admin/audit_logs/1", method: :delete)
    end.to raise_error(ActionController::RoutingError)
  end
end
