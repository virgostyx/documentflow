# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::StepsComponent, type: :component do
  let(:user) { create(:user) }
  let(:document) { create(:document, :with_workflow) }

  subject { render_inline(described_class.new(document: document, current_user: user)) }

  it "displays each step of the circuit in order" do
    expect(subject).to have_text("RED")
    expect(subject).to have_text("VISA")
    expect(subject).to have_text("SIGN")
    expect(subject).to have_text("EXP")
  end

  it "renders the steps in their defined order" do
    roles = subject.css("[data-role]").map { |node| node["data-role"] }

    expect(roles).to eq(%w[RED VISA SIGN EXP])
  end

  context "when the document has no validation circuit" do
    let(:document) { create(:document) }

    it "displays an empty state message" do
      expect(subject).to have_text("No validation circuit defined")
    end
  end

  context "when the current user can manage the circuit" do
    let(:user) { document.created_by }

    it "displays the add step form" do
      expect(subject).to have_button("Add step")
      expect(subject).to have_select("workflow_step_role")
      expect(subject).to have_select("workflow_step_actor_id")
    end

    it "displays management controls for each step" do
      expect(subject).to have_link("Remove", count: 4)
    end

    context "when the entity has circuit templates" do
      let!(:circuit_template) { create(:circuit_template, entity: document.entity, name: "Standard circuit") }

      it "displays the apply template form" do
        expect(subject).to have_select("circuit_template_id", with_options: [ "Standard circuit" ])
        expect(subject).to have_button("Apply")
      end
    end
  end

  context "when the current user cannot manage the circuit" do
    it "does not display the add step form" do
      expect(subject).not_to have_button("Add step")
      expect(subject).not_to have_link("Remove")
    end
  end

  context "when the document is in progress (not manageable) but the user can reassign" do
    let(:document) { create(:document, :with_workflow, :in_progress) }
    let(:user) { document.created_by }

    it "still displays a reassign form for each pending step" do
      expect(subject).to have_css("select[name='actor_id']", count: 4)
    end
  end

  context "when the document is in progress and the user has no special rights" do
    let(:document) { create(:document, :with_workflow, :in_progress) }

    before { create(:entity_user, entity: document.entity, user: user, status: "active") }

    it "does not display any reassign form" do
      expect(subject).not_to have_css("select[name='actor_id']")
    end
  end
end
