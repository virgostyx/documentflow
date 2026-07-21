# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::Departments", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:owner) { create(:user) }
  let(:member_user) { create(:user, email: "member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: member_user, role: "member") }

  describe "GET /entities/:entity_id/departments" do
    it "redirects to entity settings" do
      sign_in owner
      get entity_departments_path(entity)

      expect(response).to redirect_to(entity_settings_path(entity))
    end
  end

  describe "GET /entities/:entity_id/departments/new" do
    context "when the user is an owner" do
      before { sign_in owner }

      it "renders the new department form" do
        get new_entity_department_path(entity)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "redirects with an authorization error" do
        get new_entity_department_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/departments" do
    before { sign_in owner }

    context "with valid params" do
      let(:department_params) { { department: { name: "Finance & Administration", prefix: "FINANCE" } } }

      it "creates the department" do
        expect {
          post entity_departments_path(entity), params: department_params
        }.to change(entity.departments, :count).by(1)
      end

      it "redirects to entity settings" do
        post entity_departments_path(entity), params: department_params

        expect(response).to redirect_to(entity_settings_path(entity))
      end
    end

    context "with invalid params" do
      let(:department_params) { { department: { name: "" } } }

      it "does not create the department" do
        expect {
          post entity_departments_path(entity), params: department_params
        }.not_to change(Department, :count)
      end

      it "re-renders the new form" do
        post entity_departments_path(entity), params: department_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "does not create the department" do
        expect {
          post entity_departments_path(entity), params: { department: { name: "Sales" } }
        }.not_to change(Department, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/departments/:id/edit" do
    let!(:department) { create(:department, entity: entity, name: "Operations") }

    context "when the user is an owner" do
      before { sign_in owner }

      it "renders the edit form" do
        get edit_entity_department_path(entity, department)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(department.name)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "redirects with an authorization error" do
        get edit_entity_department_path(entity, department)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /entities/:entity_id/departments/:id" do
    let!(:department) { create(:department, entity: entity, name: "Operations") }

    before { sign_in owner }

    it "updates the department's name" do
      patch entity_department_path(entity, department), params: { department: { name: "Logistics" } }

      expect(department.reload.name).to eq("Logistics")
      expect(response).to redirect_to(entity_settings_path(entity))
    end

    it "updates the department's logo" do
      logo = fixture_file_upload("logo.png", "image/png")

      patch entity_department_path(entity, department), params: { department: { logo: logo } }

      expect(department.reload.logo).to be_attached
    end

    context "when a regular member attempts to update" do
      before { sign_in member_user }

      it "redirects with an authorization error" do
        patch entity_department_path(entity, department), params: { department: { name: "Hacked" } }

        expect(department.reload.name).to eq("Operations")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/departments/:id" do
    context "when the department is empty and not the default" do
      let!(:department) { create(:department, entity: entity, name: "Operations") }

      before { sign_in owner }

      it "destroys the department" do
        expect {
          delete entity_department_path(entity, department)
        }.to change(entity.departments, :count).by(-1)

        expect(response).to redirect_to(entity_settings_path(entity))
      end
    end

    context "when the department still has documents" do
      let!(:department) { create(:department, entity: entity, name: "Operations") }
      let!(:document) { create(:document, entity: entity, department: department) }

      before { sign_in owner }

      it "does not destroy the department and is redirected with an authorization error" do
        expect {
          delete entity_department_path(entity, department)
        }.not_to change(Department, :count)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the user is a regular member" do
      let!(:department) { create(:department, entity: entity, name: "Operations") }

      before { sign_in member_user }

      it "does not destroy the department" do
        expect {
          delete entity_department_path(entity, department)
        }.not_to change(Department, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
