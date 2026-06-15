# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowStepPolicy, type: :policy do
  subject(:policy) { described_class.new(user, workflow_step) }

  let(:entity) { create(:entity) }

  let(:owner)  { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)  { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:author) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }

  ACTIONS = %i[create update destroy move_up move_down apply_template].freeze

  context "when the document is a draft" do
    let(:document) { create(:document, entity: entity, created_by: author) }
    let(:workflow_step) { create(:workflow_step, document: document) }

    context "as the document's author" do
      let(:user) { author }

      it "permits managing the circuit" do
        ACTIONS.each { |action| expect(policy).to permit_action(action) }
      end
    end

    context "as entity owner" do
      let(:user) { owner }

      it "permits managing the circuit" do
        ACTIONS.each { |action| expect(policy).to permit_action(action) }
      end
    end

    context "as entity admin" do
      let(:user) { admin }

      it "permits managing the circuit" do
        ACTIONS.each { |action| expect(policy).to permit_action(action) }
      end
    end

    context "as another member" do
      let(:user) { member }

      it "does not permit managing the circuit" do
        ACTIONS.each { |action| expect(policy).not_to permit_action(action) }
      end
    end
  end

  context "when the document is in progress" do
    let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
    let(:workflow_step) { document.workflow_steps.first }

    context "as entity owner" do
      let(:user) { owner }

      it "does not permit managing the circuit" do
        ACTIONS.each { |action| expect(policy).not_to permit_action(action) }
      end
    end
  end
end
