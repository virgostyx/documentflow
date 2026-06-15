# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::Settings", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:owner) { create(:user) }
  let(:member_user) { create(:user, email: "member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: member_user, role: "member") }

  describe "GET /entities/:entity_id/settings" do
    context "when not signed in" do
      it "redirects to sign in" do
        get entity_settings_path(entity)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user is not a member of the entity" do
      let(:outsider) { create(:user) }

      before { sign_in outsider }

      it "redirects to the dashboard with an access denied alert" do
        get entity_settings_path(entity)

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the user is an owner" do
      before { sign_in owner }

      it "shows the entity name and code" do
        get entity_settings_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(entity.name)
        expect(response.body).to include(entity.code)
      end

      it "lists the members" do
        get entity_settings_path(entity)

        expect(response.body).to include(owner.email)
        expect(response.body).to include(member_user.email)
      end

      it "shows the invite member form" do
        get entity_settings_path(entity)

        expect(response.body).to include("Invite a member")
      end

      it "shows the edit and delete entity actions" do
        get entity_settings_path(entity)

        expect(response.body).to include(edit_entity_path(entity))
        expect(response.body).to include("Delete")
      end
    end

    context "when the user is a member without manage permissions" do
      before { sign_in member_user }

      it "shows the page without the invite form or edit/delete actions" do
        get entity_settings_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Invite a member")
        expect(response.body).not_to include(edit_entity_path(entity))
      end
    end
  end
end
