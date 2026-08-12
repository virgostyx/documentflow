# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::DistributionLists", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:entity) { create(:entity) }
  let(:contact) { create(:contact, entity: entity) }

  before do
    create(:entity_user, entity: entity, user: user)
    sign_in user
  end

  describe "GET /entities/:entity_id/distribution_lists" do
    it "lists the current user's distribution lists" do
      list = create(:distribution_list, user: user, name: "My partners")

      get entity_distribution_lists_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(list.name)
    end

    it "does not include another user's distribution lists" do
      other_list = create(:distribution_list, user: other_user, name: "Other's private list")

      get entity_distribution_lists_path(entity)

      expect(response.body).not_to include(other_list.name)
    end
  end

  describe "GET /entities/:entity_id/distribution_lists/new" do
    it "renders the new form" do
      get new_entity_distribution_list_path(entity)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /entities/:entity_id/distribution_lists" do
    let(:params) do
      {
        distribution_list: {
          name: "Quarterly partners",
          distribution_list_members_attributes: {
            "0" => { party_token: "Contact-#{contact.id}", position: 1, dispatch_as_attachment: "1" }
          }
        }
      }
    end

    it "creates a distribution list owned by the current user" do
      expect { post entity_distribution_lists_path(entity), params: params }.to change(user.distribution_lists, :count).by(1)

      expect(response).to redirect_to(entity_distribution_lists_path(entity))
      list = user.distribution_lists.last
      expect(list.name).to eq("Quarterly partners")
      expect(list.distribution_list_members.first.party).to eq(contact)
    end

    it "creates an empty list when no members are submitted" do
      expect {
        post entity_distribution_lists_path(entity), params: { distribution_list: { name: "Empty for now" } }
      }.to change(user.distribution_lists, :count).by(1)

      expect(response).to redirect_to(entity_distribution_lists_path(entity))
      expect(user.distribution_lists.last.distribution_list_members).to be_empty
    end

    it "re-renders the form with errors when invalid" do
      post entity_distribution_lists_path(entity), params: { distribution_list: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /entities/:entity_id/distribution_lists/:id/edit" do
    it "renders the edit form for the owner" do
      list = create(:distribution_list, user: user)

      get edit_entity_distribution_list_path(entity, list)

      expect(response).to have_http_status(:ok)
    end

    it "404s for another user's list" do
      other_list = create(:distribution_list, user: other_user)

      get edit_entity_distribution_list_path(entity, other_list)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /entities/:entity_id/distribution_lists/:id" do
    it "updates the owner's list" do
      list = create(:distribution_list, user: user, name: "Old name")

      patch entity_distribution_list_path(entity, list), params: { distribution_list: { name: "New name" } }

      expect(response).to redirect_to(entity_distribution_lists_path(entity))
      expect(list.reload.name).to eq("New name")
    end

    it "404s for another user's list" do
      other_list = create(:distribution_list, user: other_user)

      patch entity_distribution_list_path(entity, other_list), params: { distribution_list: { name: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /entities/:entity_id/distribution_lists/:id" do
    it "destroys the owner's list" do
      list = create(:distribution_list, user: user)

      expect { delete entity_distribution_list_path(entity, list) }.to change(DistributionList, :count).by(-1)
      expect(response).to redirect_to(entity_distribution_lists_path(entity))
    end

    it "404s for another user's list" do
      other_list = create(:distribution_list, user: other_user)

      delete entity_distribution_list_path(entity, other_list)

      expect(response).to have_http_status(:not_found)
    end
  end
end
