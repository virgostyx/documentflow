# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::EmailTemplates", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:owner) { create(:user) }
  let(:member_user) { create(:user, email: "member@example.com") }
  let(:other_member_user) { create(:user, email: "other-member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: member_user, role: "member") }
  let!(:other_member_membership) { create(:entity_user, entity: entity, user: other_member_user, role: "member") }

  describe "GET /entities/:entity_id/email_templates" do
    let!(:email_template) { create(:email_template, entity: entity, created_by: owner, name: "Bid call") }

    context "when not signed in" do
      it "redirects to sign in" do
        get entity_email_templates_path(entity)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "lists the entity's email templates" do
        get entity_email_templates_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(email_template.name)
      end
    end
  end

  describe "GET /entities/:entity_id/email_templates/new" do
    context "when the user is a regular member" do
      before { sign_in member_user }

      it "renders the new email template form" do
        get new_entity_email_template_path(entity)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /entities/:entity_id/email_templates" do
    before { sign_in member_user }

    context "with valid params" do
      let(:email_template_params) do
        {
          email_template: {
            name: "Bid call",
            body_template: "Dear {{recipient_name}}, please submit your bid for {{reference}} by {{deadline}}."
          }
        }
      end

      it "creates the email template" do
        expect {
          post entity_email_templates_path(entity), params: email_template_params
        }.to change(entity.email_templates, :count).by(1)
      end

      it "sets the current user as the creator" do
        post entity_email_templates_path(entity), params: email_template_params

        expect(entity.email_templates.last.created_by).to eq(member_user)
      end

      it "detects the non-reserved fields from the tags and redirects to the edit form" do
        post entity_email_templates_path(entity), params: email_template_params

        email_template = entity.email_templates.last
        expect(email_template.email_template_fields.pluck(:tag_name)).to contain_exactly("reference", "deadline")
        expect(response).to redirect_to(edit_entity_email_template_path(entity, email_template))
      end
    end

    context "with a subject_template" do
      let(:email_template_params) do
        {
          email_template: {
            name: "Bid call",
            subject_template: "Tender {{reference}}",
            body_template: "Dear {{recipient_name}}, please submit your bid for {{reference}}."
          }
        }
      end

      it "persists the subject_template" do
        post entity_email_templates_path(entity), params: email_template_params

        expect(entity.email_templates.last.subject_template).to eq("Tender {{reference}}")
      end

      it "does not duplicate a field referenced in both the subject and the body" do
        post entity_email_templates_path(entity), params: email_template_params

        expect(entity.email_templates.last.email_template_fields.pluck(:tag_name)).to contain_exactly("reference")
      end
    end

    context "with invalid params" do
      let(:email_template_params) { { email_template: { name: "" } } }

      it "does not create the email template" do
        expect {
          post entity_email_templates_path(entity), params: email_template_params
        }.not_to change(EmailTemplate, :count)
      end

      it "re-renders the new form" do
        post entity_email_templates_path(entity), params: email_template_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /entities/:entity_id/email_templates/:id/edit" do
    let!(:email_template) do
      create(:email_template, entity: entity, created_by: member_user, name: "Bid call")
    end

    context "as the creator" do
      before { sign_in member_user }

      it "renders the edit form" do
        get edit_entity_email_template_path(entity, email_template)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(email_template.name)
      end
    end

    context "as a different member" do
      before { sign_in other_member_user }

      it "redirects with an authorization error" do
        get edit_entity_email_template_path(entity, email_template)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /entities/:entity_id/email_templates/:id" do
    let!(:email_template) do
      create(:email_template, entity: entity, created_by: member_user, name: "Bid call", body_template: "Dear {{recipient_name}}, {{reference}}")
    end

    context "as the creator" do
      before { sign_in member_user }

      it "updates the email template's name" do
        patch entity_email_template_path(entity, email_template), params: {
          email_template: { name: "Renamed template" }
        }

        expect(email_template.reload.name).to eq("Renamed template")
        expect(response).to redirect_to(entity_email_templates_path(entity))
      end

      it "updates a detected field's label and type via nested attributes" do
        field = email_template.email_template_fields.find_by(tag_name: "reference")

        patch entity_email_template_path(entity, email_template), params: {
          email_template: {
            name: email_template.name,
            email_template_fields_attributes: {
              "0" => { id: field.id, label: "Reference number", field_type: "textarea", required: "0" }
            }
          }
        }

        field.reload
        expect(field.label).to eq("Reference number")
        expect(field.field_type).to eq("textarea")
        expect(field.required).to be false
      end
    end

    context "as a different member" do
      before { sign_in other_member_user }

      it "does not update the email template" do
        patch entity_email_template_path(entity, email_template), params: {
          email_template: { name: "Hacked" }
        }

        expect(email_template.reload.name).to eq("Bid call")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/email_templates/:id" do
    let!(:email_template) do
      create(:email_template, entity: entity, created_by: member_user, name: "Bid call")
    end

    context "as the creator" do
      before { sign_in member_user }

      it "destroys the email template" do
        expect {
          delete entity_email_template_path(entity, email_template)
        }.to change(entity.email_templates, :count).by(-1)

        expect(response).to redirect_to(entity_email_templates_path(entity))
      end
    end

    context "as a different member" do
      before { sign_in other_member_user }

      it "does not destroy the email template" do
        expect {
          delete entity_email_template_path(entity, email_template)
        }.not_to change(EmailTemplate, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
