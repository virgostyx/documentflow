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
end
