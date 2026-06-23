# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::ConfirmModalComponent, type: :component do
  it "renders the confirm modal element" do
    render_inline(described_class.new)

    expect(page).to have_css("#confirm-modal")
  end

  it "uses the confirm Stimulus controller" do
    render_inline(described_class.new)

    expect(page).to have_css('[data-controller="confirm"]')
  end

  it "renders confirm and cancel buttons" do
    render_inline(described_class.new)

    expect(page).to have_button("Confirm")
    expect(page).to have_button("Cancel")
  end

  it "has the modal hidden by default" do
    render_inline(described_class.new)

    expect(page).to have_css("#confirm-modal.hidden")
  end

  it "has correct aria attributes for accessibility" do
    render_inline(described_class.new)

    expect(page).to have_css('[role="dialog"]')
    expect(page).to have_css('[aria-modal="true"]')
  end
end
