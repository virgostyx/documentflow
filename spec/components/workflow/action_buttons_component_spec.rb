# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::ActionButtonsComponent, type: :component do
  let(:actor) { create(:user) }
  let(:document) { create(:document, :with_workflow, :in_progress) }

  before { document.workflow_steps.first.update!(actor: actor, status: "pending") }

  subject { render_inline(described_class.new(document: document, current_user: actor)) }

  it "displays the approve button for the current actor" do
    expect(subject).to have_button("Approve")
  end

  it "does not display the reject button for a RED actor" do
    red_step = document.workflow_steps.find_by(role: "RED")
    red_step.update!(actor: actor)

    expect(subject).not_to have_button("Reject")
  end

  it "displays the reject button for a non-RED actor" do
    visa_step = document.workflow_steps.find_by(role: "VISA")
    visa_step.update!(actor: actor, status: "pending")
    document.workflow_steps.find_by(role: "RED").update!(status: "approved")

    expect(subject).to have_button("Reject")
  end

  context "when the current user is not the current step's actor" do
    let(:other_user) { create(:user) }

    subject { render_inline(described_class.new(document: document, current_user: other_user)) }

    it "does not display the approve or reject buttons" do
      expect(subject).not_to have_button("Approve")
      expect(subject).not_to have_button("Reject")
    end
  end

  context "when the current user can cancel the document" do
    let(:document) { create(:document, :with_workflow, :in_progress, created_by: actor) }

    it "displays the cancel link" do
      expect(subject).to have_link("Cancel document")
    end
  end
end
