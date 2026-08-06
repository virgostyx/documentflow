# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::DocumentTemplates", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:owner) { create(:user) }
  let(:member_user) { create(:user, email: "member@example.com") }
  let(:other_member_user) { create(:user, email: "other-member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: member_user, role: "member") }
  let!(:other_member_membership) { create(:entity_user, entity: entity, user: other_member_user, role: "member") }

  describe "GET /entities/:entity_id/document_templates" do
    let!(:document_template) { create(:document_template, entity: entity, created_by: owner, name: "VAT exemption") }

    context "when not signed in" do
      it "redirects to sign in" do
        get entity_document_templates_path(entity)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "lists the entity's document templates" do
        get entity_document_templates_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document_template.name)
      end
    end
  end

  describe "GET /entities/:entity_id/document_templates/new" do
    context "when the user is a regular member" do
      before { sign_in member_user }

      it "renders the new document template form" do
        get new_entity_document_template_path(entity)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /entities/:entity_id/document_templates" do
    before { sign_in member_user }

    context "with valid params" do
      let(:document_template_params) do
        {
          document_template: {
            name: "VAT exemption",
            subject_template: "VAT exemption request - {{supplier}}",
            body_template: "Please exempt the purchase from {{supplier}} amounting to {{amount}}."
          }
        }
      end

      it "creates the document template" do
        expect {
          post entity_document_templates_path(entity), params: document_template_params
        }.to change(entity.document_templates, :count).by(1)
      end

      it "sets the current user as the creator" do
        post entity_document_templates_path(entity), params: document_template_params

        expect(entity.document_templates.last.created_by).to eq(member_user)
      end

      it "detects the fields from the tags and redirects to the edit form" do
        post entity_document_templates_path(entity), params: document_template_params

        document_template = entity.document_templates.last
        expect(document_template.document_template_fields.pluck(:tag_name)).to contain_exactly("supplier", "amount")
        expect(response).to redirect_to(edit_entity_document_template_path(entity, document_template))
      end
    end

    context "with invalid params" do
      let(:document_template_params) { { document_template: { name: "" } } }

      it "does not create the document template" do
        expect {
          post entity_document_templates_path(entity), params: document_template_params
        }.not_to change(DocumentTemplate, :count)
      end

      it "re-renders the new form" do
        post entity_document_templates_path(entity), params: document_template_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /entities/:entity_id/document_templates/:id/edit" do
    let!(:document_template) do
      create(:document_template, entity: entity, created_by: member_user, name: "VAT exemption")
    end

    context "as the creator" do
      before { sign_in member_user }

      it "renders the edit form" do
        get edit_entity_document_template_path(entity, document_template)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document_template.name)
      end
    end

    context "as a different member" do
      before { sign_in other_member_user }

      it "redirects with an authorization error" do
        get edit_entity_document_template_path(entity, document_template)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "as entity owner" do
      before { sign_in owner }

      it "renders the edit form" do
        get edit_entity_document_template_path(entity, document_template)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "PATCH /entities/:entity_id/document_templates/:id" do
    let!(:document_template) do
      create(
        :document_template, entity: entity, created_by: member_user, name: "VAT exemption",
        subject_template: "Request for {{supplier}}", body_template: "Body about {{supplier}}."
      )
    end

    context "as the creator" do
      before { sign_in member_user }

      it "updates the document template's name" do
        patch entity_document_template_path(entity, document_template), params: {
          document_template: { name: "Renamed template" }
        }

        expect(document_template.reload.name).to eq("Renamed template")
        expect(response).to redirect_to(entity_document_templates_path(entity))
      end

      it "updates a detected field's label and type via nested attributes" do
        field = document_template.document_template_fields.find_by(tag_name: "supplier")

        patch entity_document_template_path(entity, document_template), params: {
          document_template: {
            name: document_template.name,
            document_template_fields_attributes: {
              "0" => { id: field.id, label: "Supplier name", field_type: "textarea", required: "0" }
            }
          }
        }

        field.reload
        expect(field.label).to eq("Supplier name")
        expect(field.field_type).to eq("textarea")
        expect(field.required).to be false
      end
    end

    context "as a different member" do
      before { sign_in other_member_user }

      it "does not update the document template" do
        patch entity_document_template_path(entity, document_template), params: {
          document_template: { name: "Hacked" }
        }

        expect(document_template.reload.name).to eq("VAT exemption")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/document_templates/:id" do
    let!(:document_template) do
      create(:document_template, entity: entity, created_by: member_user, name: "VAT exemption")
    end

    context "as the creator" do
      before { sign_in member_user }

      it "destroys the document template" do
        expect {
          delete entity_document_template_path(entity, document_template)
        }.to change(entity.document_templates, :count).by(-1)

        expect(response).to redirect_to(entity_document_templates_path(entity))
      end
    end

    context "as a different member" do
      before { sign_in other_member_user }

      it "does not destroy the document template" do
        expect {
          delete entity_document_template_path(entity, document_template)
        }.not_to change(DocumentTemplate, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
