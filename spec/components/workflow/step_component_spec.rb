# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::StepComponent, type: :component do
  let(:actor) { create(:user, email: "actor@example.com") }
  let(:step) { create(:workflow_step, :visa, actor: actor, order: 2, status: "pending") }

  subject { render_inline(described_class.new(step: step)) }

  it "displays the step role" do
    expect(subject).to have_text("VISA")
  end

  it "displays the step order" do
    expect(subject).to have_text("2")
  end

  it "displays the actor's email" do
    expect(subject).to have_text("actor@example.com")
  end

  it "displays a gray badge for a pending step" do
    expect(subject).to have_css("span.bg-gray-100", text: "Pending")
  end

  context "when the step has no actor assigned" do
    let(:step) { create(:workflow_step, :visa, actor: nil) }

    it "indicates the step is unassigned" do
      expect(subject).to have_text("Unassigned")
    end
  end

  context "when the step is approved" do
    let(:step) { create(:workflow_step, :approved, actor: actor) }

    it "displays a success badge" do
      expect(subject).to have_css("span.bg-success-100", text: "Approved")
    end
  end

  context "when the step is rejected" do
    let(:step) { create(:workflow_step, :rejected, actor: actor) }

    it "displays a danger badge" do
      expect(subject).to have_css("span.bg-danger-100", text: "Rejected")
    end
  end

  context "when the step has a comment" do
    let(:step) { create(:workflow_step, :rejected, actor: actor, comment: "Missing signature") }

    it "displays the comment" do
      expect(subject).to have_text("Missing signature")
    end
  end
end
