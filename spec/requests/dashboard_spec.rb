require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    context "utilisateur non connecté" do
      it "redirige vers la connexion" do
        get dashboard_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "utilisateur connecté" do
      it "affiche le dashboard" do
        sign_in create(:user)

        get dashboard_path

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
