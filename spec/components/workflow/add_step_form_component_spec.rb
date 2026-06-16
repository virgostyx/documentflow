# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::AddStepFormComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, entity: entity) }
  let(:colleague) { create(:user, first_name: "Alice", last_name: "Martin") }

  before do
    create(:entity_user, entity: entity, user: colleague, status: "active")
  end

  subject { render_inline(described_class.new(document: document)) }

  it "renders the role select with all workflow roles" do
    expect(subject).to have_select("workflow_step_role", with_options: WorkflowStep::ROLES)
  end

  it "renders the actor select with active entity users" do
    expect(subject).to have_select("workflow_step_actor_id", with_options: [ colleague.display_name ])
  end

  it "submits to the document's workflow steps endpoint" do
    path = Rails.application.routes.url_helpers.entity_document_workflow_steps_path(entity, document)
    expect(subject).to have_css("form[action='#{path}']")
  end

  it "displays the add step button" do
    expect(subject).to have_button("Add step")
  end
end
