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
end
