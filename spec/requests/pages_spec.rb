require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /" do
    context "utilisateur non connecté" do
      it "affiche la landing page" do
        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("DocumentFlow")
      end
    end

    context "utilisateur connecté" do
      it "redirige vers le dashboard" do
        sign_in create(:user)

        get root_path

        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
