# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::ApplyCircuitTemplateOrganizer do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:document) { create(:document, entity: entity, created_by: user) }
  let(:circuit_template) { create(:circuit_template, entity: entity) }

  describe ".call" do
    context "when the template has no steps" do
      it "fails without modifying the document's circuit" do
        result = described_class.call(document: document, circuit_template: circuit_template, current_user: user)

        expect(result).not_to be_success
        expect(result.message).to include("no steps")
        expect(document.workflow_steps.reload).to be_empty
      end
    end

    context "when the template has steps" do
      let(:actor) { create(:user) }

      before do
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
        create(:circuit_template_step, circuit_template: circuit_template, role: "VISA", order: 2, actor: actor, is_parallel: true, parallel_group: 1)
      end

      context "when the document's circuit is empty" do
        it "clones the template's steps starting at order 1" do
          described_class.call(document: document, circuit_template: circuit_template, current_user: user)

          steps = document.workflow_steps.reload.ordered
          expect(steps.pluck(:role, :order)).to eq([ [ "RED", 1 ], [ "VISA", 2 ] ])
        end

        it "clones step attributes (actor, parallel flags, status)" do
          described_class.call(document: document, circuit_template: circuit_template, current_user: user)

          visa_step = document.workflow_steps.reload.find_by(role: "VISA")
          expect(visa_step.actor).to eq(actor)
          expect(visa_step.is_parallel).to be true
          expect(visa_step.parallel_group).to eq(1)
          expect(visa_step.status).to eq("pending")
        end
      end

      context "when the document's circuit already has steps" do
        before do
          create(:workflow_step, :red, document: document, order: 1, status: "approved")
        end

        it "continues the order numbering after the existing steps" do
          described_class.call(document: document, circuit_template: circuit_template, current_user: user)

          steps = document.workflow_steps.reload.ordered
          expect(steps.pluck(:role, :order)).to eq([ [ "RED", 1 ], [ "RED", 2 ], [ "VISA", 3 ] ])
        end
      end

      it "records an audit log" do
        expect {
          described_class.call(document: document, circuit_template: circuit_template, current_user: user)
        }.to change(AuditLog, :count).by(1)
      end

      it "succeeds" do
        result = described_class.call(document: document, circuit_template: circuit_template, current_user: user)

        expect(result).to be_success
      end
    end
  end
end
