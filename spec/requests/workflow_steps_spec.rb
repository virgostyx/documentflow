# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkflowSteps", type: :request do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity) }

  before do
    document.workflow_steps.find_by(role: "RED")&.update!(status: "approved")
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/:id/approve" do
    let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

    context "as the step's actor" do
      before do
        create(:entity_user, entity: entity, user: visa_step.actor)
        sign_in visa_step.actor
      end

      it "approves the step" do
        post approve_entity_document_workflow_step_path(entity, document, visa_step)

        expect(visa_step.reload).to be_approved
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "as another user" do
      let(:other_user) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other_user)
        sign_in other_user
      end

      it "does not approve the step" do
        post approve_entity_document_workflow_step_path(entity, document, visa_step)

        expect(visa_step.reload).to be_pending
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        post approve_entity_document_workflow_step_path(entity, document, visa_step)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/:id/reject" do
    let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

    context "as the step's actor" do
      before do
        create(:entity_user, entity: entity, user: visa_step.actor)
        sign_in visa_step.actor
      end

      it "rejects the step with the given reason" do
        post reject_entity_document_workflow_step_path(entity, document, visa_step), params: { reason: "Missing signature" }

        expect(visa_step.reload).to be_rejected
        expect(visa_step.comment).to eq("Missing signature")
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "as the RED actor" do
      let(:red_step) { document.workflow_steps.find_by(role: "RED") }

      before do
        create(:entity_user, entity: entity, user: red_step.actor)
        sign_in red_step.actor
      end

      it "does not reject the step" do
        post reject_entity_document_workflow_step_path(entity, document, red_step), params: { reason: "Not convinced" }

        expect(red_step.reload).to be_approved
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "as another user" do
      let(:other_user) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other_user)
        sign_in other_user
      end

      it "does not reject the step" do
        post reject_entity_document_workflow_step_path(entity, document, visa_step), params: { reason: "Not convinced" }

        expect(visa_step.reload).to be_pending
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "adds a new step at the end of the circuit" do
        expect {
          post entity_document_workflow_steps_path(entity, document),
               params: { workflow_step: { role: "VISA" } }
        }.to change(document.workflow_steps, :count).by(1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present

        new_step = document.workflow_steps.order(:order).last
        expect(new_step.role).to eq("VISA")
        expect(new_step.order).to eq(1)
        expect(new_step).to be_pending
      end

      it "appends after existing steps" do
        create(:workflow_step, :red, document: document, order: 1)
        create(:workflow_step, :visa, document: document, order: 2)

        post entity_document_workflow_steps_path(entity, document),
             params: { workflow_step: { role: "SIGN" } }

        expect(document.workflow_steps.order(:order).last.order).to eq(3)
      end

      it "assigns the selected actor and parallel options" do
        colleague = create(:user)
        create(:entity_user, entity: entity, user: colleague, status: "active")

        post entity_document_workflow_steps_path(entity, document),
             params: { workflow_step: { role: "VISA", actor_id: colleague.id, is_parallel: "1", parallel_group: 1 } }

        new_step = document.workflow_steps.order(:order).last
        expect(new_step.actor).to eq(colleague)
        expect(new_step).to be_parallel
        expect(new_step.parallel_group).to eq(1)
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }

      before do
        create(:entity_user, :owner, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "does not add a step" do
        expect {
          post entity_document_workflow_steps_path(entity, document),
               params: { workflow_step: { role: "VISA" } }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest who is not the document's author" do
      let(:guest) { create(:user) }

      before do
        create(:entity_user, :guest, entity: entity, user: guest, status: "active")
        sign_in guest
      end

      it "does not add a step" do
        expect {
          post entity_document_workflow_steps_path(entity, document),
               params: { workflow_step: { role: "VISA" } }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /entities/:entity_id/documents/:document_id/workflow_steps/:id" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let!(:step) { create(:workflow_step, :red, document: document, order: 1) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "updates the step" do
        colleague = create(:user)
        create(:entity_user, entity: entity, user: colleague, status: "active")

        patch entity_document_workflow_step_path(entity, document, step),
              params: { workflow_step: { role: "VISA", actor_id: colleague.id } }

        expect(step.reload.role).to eq("VISA")
        expect(step.actor).to eq(colleague)
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
      let!(:step) { document.workflow_steps.find_by(role: "VISA") }

      before do
        create(:entity_user, :owner, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "does not update the step" do
        patch entity_document_workflow_step_path(entity, document, step),
              params: { workflow_step: { role: "SIGN" } }

        expect(step.reload.role).to eq("VISA")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:document_id/workflow_steps/:id" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let!(:step) { create(:workflow_step, :red, document: document, order: 1) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "removes the step from the circuit" do
        expect {
          delete entity_document_workflow_step_path(entity, document, step)
        }.to change(document.workflow_steps, :count).by(-1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
      let!(:step) { document.workflow_steps.find_by(role: "VISA") }

      before do
        create(:entity_user, :owner, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "does not remove the step" do
        expect {
          delete entity_document_workflow_step_path(entity, document, step)
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/apply_template" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let(:circuit_template) { create(:circuit_template, entity: entity) }

    before do
      create(:entity_user, entity: entity, user: author, status: "active")
      sign_in author
    end

    context "when the template has steps" do
      before do
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
        create(:circuit_template_step, circuit_template: circuit_template, role: "VISA", order: 2)
      end

      it "clones the template's steps into the document's circuit" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.to change(document.workflow_steps, :count).by(2)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.workflow_steps.reload.ordered.pluck(:role)).to eq(%w[RED VISA])
      end

      it "continues the order numbering after existing steps" do
        create(:workflow_step, :red, document: document, order: 1)

        post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }

        expect(document.workflow_steps.reload.ordered.pluck(:order)).to eq([ 1, 2, 3 ])
      end
    end

    context "when the template has no steps" do
      it "does not add any steps and shows an error" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }

      before do
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
      end

      it "does not apply the template" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest who is not the document's author" do
      let(:guest) { create(:user) }

      before do
        create(:entity_user, :guest, entity: entity, user: guest, status: "active")
        sign_in guest
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
      end

      it "does not apply the template" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/:id/move_up and /move_down" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let!(:first_step) { create(:workflow_step, :red, document: document, order: 1) }
    let!(:second_step) { create(:workflow_step, :visa, document: document, order: 2) }

    before do
      create(:entity_user, entity: entity, user: author, status: "active")
      sign_in author
    end

    it "moves a step down, swapping its order with the next step" do
      post move_down_entity_document_workflow_step_path(entity, document, first_step)

      expect(response).to redirect_to(entity_document_path(entity, document))
      expect(flash[:notice]).to be_present
      expect(first_step.reload.order).to eq(2)
      expect(second_step.reload.order).to eq(1)
    end

    it "moves a step up, swapping its order with the previous step" do
      post move_up_entity_document_workflow_step_path(entity, document, second_step)

      expect(first_step.reload.order).to eq(2)
      expect(second_step.reload.order).to eq(1)
    end

    it "does nothing when moving the first step up" do
      post move_up_entity_document_workflow_step_path(entity, document, first_step)

      expect(first_step.reload.order).to eq(1)
      expect(second_step.reload.order).to eq(2)
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
      let!(:first_step) { document.workflow_steps.find_by(role: "RED") }
      let!(:second_step) { document.workflow_steps.find_by(role: "VISA") }

      it "does not move the step" do
        post move_down_entity_document_workflow_step_path(entity, document, first_step)

        expect(first_step.reload.order).to eq(1)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
