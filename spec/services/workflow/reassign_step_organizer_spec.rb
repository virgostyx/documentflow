# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::ReassignStepOrganizer do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: owner) }
  let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }
  let(:previous_actor) { visa_step.actor }
  let(:new_actor) { create(:user) }

  before { create(:entity_user, :owner, entity: entity, user: owner, status: "active") }

  describe ".call" do
    context "when the new actor is an active member of the entity" do
      before { create(:entity_user, entity: entity, user: new_actor, role: "member", status: "active") }

      it "reassigns the step to the new actor" do
        result = described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)

        expect(result).to be_success
        expect(visa_step.reload.actor).to eq(new_actor)
      end

      it "notifies the new actor" do
        expect(NotificationJob).to receive(:perform_later).with(new_actor.id, "action_required", document.id)

        described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)
      end

      it "broadcasts the workflow steps update to the newly assigned actor" do
        expect(WorkflowStepsBroadcastJob).to receive(:perform_later).with(new_actor.id, document.id)

        described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)
      end

      it "records an audit log" do
        expect {
          described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "when the new actor is not an active member of the entity" do
      it "fails and does not change the step's actor" do
        result = described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)

        expect(result).not_to be_success
        expect(visa_step.reload.actor).to eq(previous_actor)
      end

      it "does not notify anyone" do
        expect(NotificationJob).not_to receive(:perform_later)

        described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)
      end

      it "does not broadcast a workflow steps update" do
        expect(WorkflowStepsBroadcastJob).not_to receive(:perform_later)

        described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)
      end
    end

    context "when the new actor's membership in the entity is suspended" do
      before { create(:entity_user, entity: entity, user: new_actor, role: "member", status: "suspended") }

      it "fails and does not change the step's actor" do
        result = described_class.call(step: visa_step, new_actor: new_actor, current_user: owner)

        expect(result).not_to be_success
        expect(visa_step.reload.actor).to eq(previous_actor)
      end
    end
  end
end
