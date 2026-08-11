# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::DistributionLists", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:entity) { create(:entity) }
  let(:contact) { create(:contact, entity: entity) }

  before { sign_in user }

  describe "GET /distribution_lists" do
    it "lists the current user's distribution lists" do
      list = create(:distribution_list, user: user, name: "My partners")

      get distribution_lists_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(list.name)
    end

    it "does not include another user's distribution lists" do
      other_list = create(:distribution_list, user: other_user, name: "Other's private list")

      get distribution_lists_path

      expect(response.body).not_to include(other_list.name)
    end
  end

  describe "GET /distribution_lists/new" do
    it "renders the new form" do
      get new_distribution_list_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /distribution_lists" do
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
      expect { post distribution_lists_path, params: params }.to change(user.distribution_lists, :count).by(1)

      expect(response).to redirect_to(distribution_lists_path)
      list = user.distribution_lists.last
      expect(list.name).to eq("Quarterly partners")
      expect(list.distribution_list_members.first.party).to eq(contact)
    end

    it "creates an empty list when no members are submitted" do
      expect {
        post distribution_lists_path, params: { distribution_list: { name: "Empty for now" } }
      }.to change(user.distribution_lists, :count).by(1)

      expect(response).to redirect_to(distribution_lists_path)
      expect(user.distribution_lists.last.distribution_list_members).to be_empty
    end

    it "re-renders the form with errors when invalid" do
      post distribution_lists_path, params: { distribution_list: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /distribution_lists/:id/edit" do
    it "renders the edit form for the owner" do
      list = create(:distribution_list, user: user)

      get edit_distribution_list_path(list)

      expect(response).to have_http_status(:ok)
    end

    it "404s for another user's list" do
      other_list = create(:distribution_list, user: other_user)

      get edit_distribution_list_path(other_list)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /distribution_lists/:id" do
    it "updates the owner's list" do
      list = create(:distribution_list, user: user, name: "Old name")

      patch distribution_list_path(list), params: { distribution_list: { name: "New name" } }

      expect(response).to redirect_to(distribution_lists_path)
      expect(list.reload.name).to eq("New name")
    end

    it "404s for another user's list" do
      other_list = create(:distribution_list, user: other_user)

      patch distribution_list_path(other_list), params: { distribution_list: { name: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /distribution_lists/:id" do
    it "destroys the owner's list" do
      list = create(:distribution_list, user: user)

      expect { delete distribution_list_path(list) }.to change(DistributionList, :count).by(-1)
      expect(response).to redirect_to(distribution_lists_path)
    end

    it "404s for another user's list" do
      other_list = create(:distribution_list, user: other_user)

      delete distribution_list_path(other_list)

      expect(response).to have_http_status(:not_found)
    end
  end
end
