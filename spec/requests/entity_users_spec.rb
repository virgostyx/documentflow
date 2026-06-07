# frozen_string_literal: true

require "rails_helper"

RSpec.describe "EntityUsers", type: :request do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let(:member_user) { create(:user, email: "member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: member_user, role: "member") }

  describe "GET /entities/:entity_id/entity_users (EntityScoped behavior)" do
    context "when not signed in" do
      it "redirects to sign in" do
        get entity_entity_users_path(entity)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the entity does not exist" do
      before { sign_in owner }

      it "redirects to the dashboard with an alert" do
        get entity_entity_users_path(entity_id: -1)

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the user is not a member of the entity" do
      let(:outsider) { create(:user) }
      before { sign_in outsider }

      it "redirects to the dashboard with an access denied alert" do
        get entity_entity_users_path(entity)

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the user is an active member of the entity" do
      before { sign_in member_user }

      it "lists the members" do
        get entity_entity_users_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(owner.email)
        expect(response.body).to include(member_user.email)
      end
    end
  end

  describe "POST /entities/:entity_id/entity_users (invite a member)" do
    let(:invite_params) { { entity_user: { invited_email: "new@example.com", role: "member" } } }

    context "when the current user can manage members" do
      before { sign_in owner }

      it "creates a pending invitation" do
        expect {
          post entity_entity_users_path(entity), params: invite_params
        }.to change(EntityUser, :count).by(1)

        invitation = entity.entity_users.find_by(invited_email: "new@example.com")
        expect(invitation).to be_pending
      end

      it "redirects back to the members page" do
        post entity_entity_users_path(entity), params: invite_params

        expect(response).to redirect_to(entity_entity_users_path(entity))
        expect(flash[:notice]).to be_present
      end
    end

    context "when the current user cannot manage members" do
      before { sign_in member_user }

      it "does not create an invitation and is redirected with an authorization error" do
        expect {
          post entity_entity_users_path(entity), params: invite_params
        }.not_to change(EntityUser, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /entities/:entity_id/entity_users/:id (change role)" do
    context "when the current user can manage members" do
      before { sign_in owner }

      it "updates the member's role" do
        patch entity_entity_user_path(entity, member_membership), params: { entity_user: { role: "admin" } }

        expect(member_membership.reload.role).to eq("admin")
        expect(response).to redirect_to(entity_entity_users_path(entity))
      end
    end

    context "when the current user cannot manage members" do
      before { sign_in member_user }

      it "does not change the role" do
        patch entity_entity_user_path(entity, owner_membership), params: { entity_user: { role: "member" } }

        expect(owner_membership.reload.role).to eq("owner")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/entity_users/:id (remove a member)" do
    context "when the current user can manage members" do
      before { sign_in owner }

      it "removes the member" do
        expect {
          delete entity_entity_user_path(entity, member_membership)
        }.to change(EntityUser, :count).by(-1)

        expect(response).to redirect_to(entity_entity_users_path(entity))
      end
    end

    context "when the current user cannot manage members" do
      before { sign_in member_user }

      it "does not remove the member and is redirected with an authorization error" do
        expect {
          delete entity_entity_user_path(entity, owner_membership)
        }.not_to change(EntityUser, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
