# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin entities", type: :request do
  let(:super_admin) do
    create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)
  end

  describe "GET /admin/entities" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/admin/entities"

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular signed-in user" do
      before { sign_in create(:user) }

      it "redirects with an authorization alert" do
        get "/admin/entities"

        expect(response).to redirect_to("/")
        expect(flash[:alert]).to be_present
      end
    end

    context "as a super admin" do
      before { sign_in super_admin }

      it "lists entities" do
        entity = create(:entity, name: "Acme Corp")

        get "/admin/entities"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Acme Corp")
        expect(response.body).to include(entity.prefix)
      end
    end
  end

  describe "GET /admin/entities/:id" do
    before { sign_in super_admin }

    it "shows the entity" do
      entity = create(:entity, name: "Acme Corp")

      get "/admin/entities/#{entity.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Acme Corp")
    end
  end
end
