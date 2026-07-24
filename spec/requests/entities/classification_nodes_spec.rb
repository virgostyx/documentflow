# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::ClassificationNodes", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:owner) { create(:user) }
  let(:regular_member) { create(:user, email: "member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: regular_member, role: "member") }

  describe "GET /entities/:entity_id/classification_nodes" do
    it "lists the entity's classification nodes" do
      node = create(:classification_node, entity: entity, code: "1", name: "Contracts")
      sign_in owner

      get entity_classification_nodes_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(node.name)
    end
  end

  describe "GET /entities/:entity_id/classification_nodes/new" do
    context "as owner" do
      before { sign_in owner }

      it "renders the new node form for a root node" do
        get new_entity_classification_node_path(entity)

        expect(response).to have_http_status(:ok)
      end

      it "renders the new node form for a child node" do
        root = create(:classification_node, entity: entity, code: "1", name: "Contracts")

        get new_entity_classification_node_path(entity, parent_id: root.id)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as a regular member (not owner/admin)" do
      before { sign_in regular_member }

      it "redirects with an authorization error" do
        get new_entity_classification_node_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/classification_nodes" do
    before { sign_in owner }

    context "with valid params" do
      let(:node_params) { { classification_node: { code: "1", name: "Contracts" } } }

      it "creates the node" do
        expect {
          post entity_classification_nodes_path(entity), params: node_params
        }.to change(ClassificationNode, :count).by(1)
      end

      it "redirects to the index" do
        post entity_classification_nodes_path(entity), params: node_params

        expect(response).to redirect_to(entity_classification_nodes_path(entity))
      end
    end

    context "with invalid params" do
      let(:node_params) { { classification_node: { code: "", name: "Contracts" } } }

      it "does not create the node" do
        expect {
          post entity_classification_nodes_path(entity), params: node_params
        }.not_to change(ClassificationNode, :count)
      end

      it "re-renders the new form" do
        post entity_classification_nodes_path(entity), params: node_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "replaces the modal frame in place when the request is a turbo stream, instead of breaking out to the top" do
        post entity_classification_nodes_path(entity), params: node_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('turbo-stream action="replace" target="modal"')
      end
    end

    context "as a regular member (not owner/admin)" do
      before { sign_in regular_member }

      it "does not create the node" do
        expect {
          post entity_classification_nodes_path(entity), params: { classification_node: { code: "1", name: "Contracts" } }
        }.not_to change(ClassificationNode, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/classification_nodes/:id/edit" do
    let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }

    context "as owner" do
      before { sign_in owner }

      it "renders the edit form" do
        get edit_entity_classification_node_path(entity, node)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(node.name)
      end
    end

    context "as a regular member (not owner/admin)" do
      before { sign_in regular_member }

      it "redirects with an authorization error" do
        get edit_entity_classification_node_path(entity, node)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /entities/:entity_id/classification_nodes/:id" do
    let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }

    before { sign_in owner }

    it "updates the node's name" do
      patch entity_classification_node_path(entity, node), params: { classification_node: { name: "Invoices" } }

      expect(node.reload.name).to eq("Invoices")
      expect(response).to redirect_to(entity_classification_nodes_path(entity))
    end

    context "with invalid params" do
      it "does not update the node" do
        patch entity_classification_node_path(entity, node), params: { classification_node: { code: "01" } }

        expect(node.reload.code).to eq("1")
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "replaces the modal frame in place when the request is a turbo stream, instead of breaking out to the top" do
        patch entity_classification_node_path(entity, node), params: { classification_node: { code: "01" } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('turbo-stream action="replace" target="modal"')
      end
    end

    context "as a regular member (not owner/admin)" do
      before { sign_in regular_member }

      it "does not update the node" do
        patch entity_classification_node_path(entity, node), params: { classification_node: { name: "Hacked" } }

        expect(node.reload.name).to eq("Contracts")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/classification_nodes/:id/confirm_destroy" do
    let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }

    before { sign_in owner }

    it "renders the confirmation" do
      get confirm_destroy_entity_classification_node_path(entity, node)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(node.name)
    end
  end

  describe "DELETE /entities/:entity_id/classification_nodes/:id" do
    context "when the node is empty" do
      let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }

      before { sign_in owner }

      it "destroys the node" do
        expect {
          delete entity_classification_node_path(entity, node)
        }.to change(ClassificationNode, :count).by(-1)

        expect(response).to redirect_to(entity_classification_nodes_path(entity))
      end
    end

    context "when the node still has documents" do
      let(:department) { create(:department, entity: entity) }
      let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }
      let!(:document) { create(:document, entity: entity, department: department, classification_node: node) }

      before { sign_in owner }

      it "does not destroy the node" do
        expect {
          delete entity_classification_node_path(entity, node)
        }.not_to change(ClassificationNode, :count)

        expect(response).to redirect_to(entity_classification_nodes_path(entity))
        expect(flash[:alert]).to be_present
      end
    end

    context "when the node still has children" do
      let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }
      let!(:child) { create(:classification_node, entity: entity, parent: node, code: "1.1", name: "Drafts") }

      before { sign_in owner }

      it "does not destroy the node" do
        expect {
          delete entity_classification_node_path(entity, node)
        }.not_to change(ClassificationNode, :count)

        expect(response).to redirect_to(entity_classification_nodes_path(entity))
        expect(flash[:alert]).to be_present
      end
    end

    context "as a regular member (not owner/admin)" do
      let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }

      before { sign_in regular_member }

      it "does not destroy the node" do
        expect {
          delete entity_classification_node_path(entity, node)
        }.not_to change(ClassificationNode, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
