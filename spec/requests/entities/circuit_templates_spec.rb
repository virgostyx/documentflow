# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::CircuitTemplates", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:owner) { create(:user) }
  let(:member_user) { create(:user, email: "member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: member_user, role: "member") }

  describe "GET /entities/:entity_id/circuit_templates" do
    let!(:circuit_template) { create(:circuit_template, entity: entity, name: "Standard circuit") }

    context "when not signed in" do
      it "redirects to sign in" do
        get entity_circuit_templates_path(entity)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user is an owner" do
      before { sign_in owner }

      it "lists the entity's circuit templates" do
        get entity_circuit_templates_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(circuit_template.name)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "redirects with an authorization error" do
        get entity_circuit_templates_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /entities/:entity_id/circuit_templates/new" do
    context "when the user is an owner" do
      before { sign_in owner }

      it "renders the new circuit template form" do
        get new_entity_circuit_template_path(entity)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "redirects with an authorization error" do
        get new_entity_circuit_template_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/circuit_templates" do
    before { sign_in owner }

    context "with valid params" do
      let(:colleague) { create(:user) }
      let!(:colleague_membership) { create(:entity_user, entity: entity, user: colleague, status: "active") }

      let(:circuit_template_params) do
        {
          circuit_template: {
            name: "Standard approval",
            circuit_template_steps_attributes: {
              "0" => { role: "RED", order: 1, actor_id: colleague.id },
              "1" => { role: "VISA", order: 2 }
            }
          }
        }
      end

      it "creates the circuit template with its steps" do
        expect {
          post entity_circuit_templates_path(entity), params: circuit_template_params
        }.to change(entity.circuit_templates, :count).by(1)

        expect(entity.circuit_templates.last.circuit_template_steps.count).to eq(2)
      end

      it "redirects to the circuit templates list" do
        post entity_circuit_templates_path(entity), params: circuit_template_params

        expect(response).to redirect_to(entity_circuit_templates_path(entity))
      end
    end

    context "with invalid params" do
      let(:circuit_template_params) { { circuit_template: { name: "" } } }

      it "does not create the circuit template" do
        expect {
          post entity_circuit_templates_path(entity), params: circuit_template_params
        }.not_to change(CircuitTemplate, :count)
      end

      it "re-renders the new form" do
        post entity_circuit_templates_path(entity), params: circuit_template_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /entities/:entity_id/circuit_templates/:id/edit" do
    let!(:circuit_template) { create(:circuit_template, entity: entity, name: "Standard circuit") }

    context "when the user is an owner" do
      before { sign_in owner }

      it "renders the edit form" do
        get edit_entity_circuit_template_path(entity, circuit_template)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(circuit_template.name)
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "redirects with an authorization error" do
        get edit_entity_circuit_template_path(entity, circuit_template)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /entities/:entity_id/circuit_templates/:id" do
    let!(:circuit_template) { create(:circuit_template, entity: entity, name: "Standard circuit") }
    let!(:step) { create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1) }

    before { sign_in owner }

    it "updates the circuit template's name" do
      patch entity_circuit_template_path(entity, circuit_template), params: { circuit_template: { name: "Renamed circuit" } }

      expect(circuit_template.reload.name).to eq("Renamed circuit")
      expect(response).to redirect_to(entity_circuit_templates_path(entity))
    end

    it "adds a new step via nested attributes" do
      patch entity_circuit_template_path(entity, circuit_template), params: {
        circuit_template: {
          name: circuit_template.name,
          circuit_template_steps_attributes: {
            "0" => { id: step.id, role: "RED", order: 1 },
            "1" => { role: "VISA", order: 2 }
          }
        }
      }

      expect(circuit_template.circuit_template_steps.reload.count).to eq(2)
    end

    it "removes a step via nested attributes" do
      patch entity_circuit_template_path(entity, circuit_template), params: {
        circuit_template: {
          name: circuit_template.name,
          circuit_template_steps_attributes: {
            "0" => { id: step.id, role: "RED", order: 1, _destroy: "1" }
          }
        }
      }

      expect(circuit_template.circuit_template_steps.reload).to be_empty
    end

    context "when a regular member attempts to update" do
      before { sign_in member_user }

      it "redirects with an authorization error" do
        patch entity_circuit_template_path(entity, circuit_template), params: { circuit_template: { name: "Hacked" } }

        expect(circuit_template.reload.name).to eq("Standard circuit")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/circuit_templates/:id" do
    let!(:circuit_template) { create(:circuit_template, entity: entity, name: "Standard circuit") }

    context "when the user is an owner" do
      before { sign_in owner }

      it "destroys the circuit template" do
        expect {
          delete entity_circuit_template_path(entity, circuit_template)
        }.to change(entity.circuit_templates, :count).by(-1)

        expect(response).to redirect_to(entity_circuit_templates_path(entity))
      end
    end

    context "when the user is a regular member" do
      before { sign_in member_user }

      it "does not destroy the circuit template" do
        expect {
          delete entity_circuit_template_path(entity, circuit_template)
        }.not_to change(CircuitTemplate, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
