require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to sign in" do
        get dashboard_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "displays the dashboard" do
        get dashboard_path

        expect(response).to have_http_status(:ok)
      end

      context "when the user belongs to entities" do
        let!(:entity) { create(:entity, name: "Acme Corp") }

        before { create(:entity_user, :owner, entity: entity, user: user) }

        it "lists the user's entities" do
          get dashboard_path

          expect(response.body).to include("Acme Corp")
        end
      end

      context "when the user does not belong to any entity" do
        it "displays an empty state with a link to create an entity" do
          get dashboard_path

          expect(response.body).to include("No entities yet")
          expect(response.body).to include(new_entity_path)
        end
      end
    end
  end
end
