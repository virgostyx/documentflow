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

      context "when the user belongs to a single entity" do
        let!(:entity) { create(:entity, name: "Acme Corp") }

        before { create(:entity_user, :owner, entity: entity, user: user) }

        it "redirects straight to that entity's documents" do
          get dashboard_path

          expect(response).to redirect_to(entity_documents_path(entity))
        end
      end

      context "when the user belongs to multiple entities" do
        let!(:entity) { create(:entity, name: "Acme Corp") }
        let!(:other_entity) { create(:entity, name: "Northbridge") }

        before do
          create(:entity_user, :owner, entity: entity, user: user)
          create(:entity_user, :owner, entity: other_entity, user: user)
        end

        it "lists the user's entities" do
          get dashboard_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Acme Corp")
          expect(response.body).to include("Northbridge")
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
