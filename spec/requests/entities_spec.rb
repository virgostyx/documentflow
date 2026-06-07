# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities", type: :request do
  let(:user) { create(:user) }

  describe "GET /entities" do
    context "when not signed in" do
      it "redirects to sign in" do
        get entities_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let!(:my_entity) { create(:entity) }
      let!(:other_entity) { create(:entity) }

      before do
        create(:entity_user, :owner, entity: my_entity, user: user)
        sign_in user
      end

      it "lists only the entities the user belongs to" do
        get entities_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(my_entity.name)
        expect(response.body).not_to include(other_entity.name)
      end
    end
  end

  describe "GET /entities/new" do
    before { sign_in user }

    it "renders the new entity form" do
      get new_entity_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /entities" do
    before { sign_in user }

    context "with valid params" do
      let(:entity_params) { { entity: { name: "Acme Corp" } } }

      it "creates the entity" do
        expect {
          post entities_path, params: entity_params
        }.to change(Entity, :count).by(1)
      end

      it "makes the current user the owner" do
        post entities_path, params: entity_params

        entity = Entity.find_by(name: "Acme Corp")
        expect(entity.entity_users.find_by(user: user)).to be_owner
      end

      it "redirects to the entity page" do
        post entities_path, params: entity_params

        entity = Entity.find_by(name: "Acme Corp")
        expect(response).to redirect_to(entity_path(entity))
      end
    end

    context "with invalid params" do
      let(:entity_params) { { entity: { name: "" } } }

      it "does not create an entity" do
        expect {
          post entities_path, params: entity_params
        }.not_to change(Entity, :count)
      end

      it "renders the new form again" do
        post entities_path, params: entity_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /entities/:id" do
    let(:entity) { create(:entity) }

    context "when the user is a member" do
      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "shows the entity" do
        get entity_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(entity.name)
      end
    end

    context "when the user is not a member" do
      before { sign_in user }

      it "redirects with an authorization error" do
        get entity_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /entities/:id/edit" do
    let(:entity) { create(:entity) }

    context "when the user is an owner" do
      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "renders the edit form" do
        get edit_entity_path(entity)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is a guest" do
      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        get edit_entity_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /entities/:id" do
    let(:entity) { create(:entity, name: "Old Name") }

    context "when the user is an owner" do
      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "updates the entity" do
        patch entity_path(entity), params: { entity: { name: "New Name" } }

        expect(entity.reload.name).to eq("New Name")
        expect(response).to redirect_to(entity_path(entity))
      end
    end

    context "when the user is a member" do
      before do
        create(:entity_user, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        patch entity_path(entity), params: { entity: { name: "New Name" } }

        expect(entity.reload.name).to eq("Old Name")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:id" do
    let!(:entity) { create(:entity) }

    context "when the user is an owner" do
      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "destroys the entity" do
        expect {
          delete entity_path(entity)
        }.to change(Entity, :count).by(-1)

        expect(response).to redirect_to(dashboard_path)
      end
    end

    context "when the user is an admin" do
      before do
        create(:entity_user, :admin, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        expect {
          delete entity_path(entity)
        }.not_to change(Entity, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
