# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::Folders", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:department) { create(:department, entity: entity, name: "Finance") }
  let(:owner) { create(:user) }
  let(:outsider_member) { create(:user, email: "outsider@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:outsider_membership) { create(:entity_user, entity: entity, user: outsider_member, role: "member") }

  describe "GET /entities/:entity_id/folders" do
    it "lists the entity's departments and their folders" do
      folder = create(:folder, entity: entity, department: department, name: "Contracts")
      sign_in owner

      get entity_folders_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(department.name)
      expect(response.body).to include(folder.name)
    end
  end

  describe "GET /entities/:entity_id/folders/new" do
    context "as owner" do
      before { sign_in owner }

      it "renders the new folder form for a root folder" do
        get new_entity_folder_path(entity, department_id: department.id)

        expect(response).to have_http_status(:ok)
      end

      it "renders the new folder form for a subfolder" do
        root = create(:folder, entity: entity, department: department)

        get new_entity_folder_path(entity, department_id: department.id, parent_id: root.id)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as a member with no access to the department" do
      before { sign_in outsider_member }

      it "redirects with an authorization error" do
        get new_entity_folder_path(entity, department_id: department.id)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/folders" do
    before { sign_in owner }

    context "with valid params" do
      let(:folder_params) { { folder: { name: "Contracts", department_id: department.id } } }

      it "creates the folder" do
        expect {
          post entity_folders_path(entity), params: folder_params
        }.to change(Folder, :count).by(1)
      end

      it "redirects to the folders index" do
        post entity_folders_path(entity), params: folder_params

        expect(response).to redirect_to(entity_folders_path(entity))
      end
    end

    context "with invalid params" do
      let(:folder_params) { { folder: { name: "", department_id: department.id } } }

      it "does not create the folder" do
        expect {
          post entity_folders_path(entity), params: folder_params
        }.not_to change(Folder, :count)
      end

      it "re-renders the new form" do
        post entity_folders_path(entity), params: folder_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "as a member with no access to the department" do
      before { sign_in outsider_member }

      it "does not create the folder" do
        expect {
          post entity_folders_path(entity), params: { folder: { name: "Sales", department_id: department.id } }
        }.not_to change(Folder, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/folders/:id/edit" do
    let!(:folder) { create(:folder, entity: entity, department: department, name: "Contracts") }

    context "as owner" do
      before { sign_in owner }

      it "renders the edit form" do
        get edit_entity_folder_path(entity, folder)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(folder.name)
      end
    end

    context "as a member with no access to the department" do
      before { sign_in outsider_member }

      it "redirects with an authorization error" do
        get edit_entity_folder_path(entity, folder)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /entities/:entity_id/folders/:id" do
    let!(:folder) { create(:folder, entity: entity, department: department, name: "Contracts") }

    before { sign_in owner }

    it "updates the folder's name" do
      patch entity_folder_path(entity, folder), params: { folder: { name: "Invoices" } }

      expect(folder.reload.name).to eq("Invoices")
      expect(response).to redirect_to(entity_folders_path(entity))
    end

    context "as a member with no access to the department" do
      before { sign_in outsider_member }

      it "does not update the folder" do
        patch entity_folder_path(entity, folder), params: { folder: { name: "Hacked" } }

        expect(folder.reload.name).to eq("Contracts")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/folders/:id/confirm_destroy" do
    let!(:folder) { create(:folder, entity: entity, department: department, name: "Contracts") }

    before { sign_in owner }

    it "renders the confirmation" do
      get confirm_destroy_entity_folder_path(entity, folder)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(folder.name)
    end
  end

  describe "DELETE /entities/:entity_id/folders/:id" do
    context "when the folder is empty" do
      let!(:folder) { create(:folder, entity: entity, department: department, name: "Contracts") }

      before { sign_in owner }

      it "destroys the folder" do
        expect {
          delete entity_folder_path(entity, folder)
        }.to change(Folder, :count).by(-1)

        expect(response).to redirect_to(entity_folders_path(entity))
      end
    end

    context "when the folder still has documents" do
      let!(:folder) { create(:folder, entity: entity, department: department, name: "Contracts") }
      let!(:document) { create(:document, entity: entity, department: department, folder: folder) }

      before { sign_in owner }

      it "does not destroy the folder" do
        expect {
          delete entity_folder_path(entity, folder)
        }.not_to change(Folder, :count)

        expect(response).to redirect_to(entity_folders_path(entity))
        expect(flash[:alert]).to be_present
      end
    end

    context "when the folder still has subfolders" do
      let!(:folder) { create(:folder, entity: entity, department: department, name: "Contracts") }
      let!(:subfolder) { create(:folder, entity: entity, department: department, parent: folder) }

      before { sign_in owner }

      it "does not destroy the folder" do
        expect {
          delete entity_folder_path(entity, folder)
        }.not_to change(Folder, :count)

        expect(response).to redirect_to(entity_folders_path(entity))
        expect(flash[:alert]).to be_present
      end
    end

    context "as a member with no access to the department" do
      let!(:folder) { create(:folder, entity: entity, department: department, name: "Contracts") }

      before { sign_in outsider_member }

      it "does not destroy the folder" do
        expect {
          delete entity_folder_path(entity, folder)
        }.not_to change(Folder, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
