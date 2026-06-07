# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::DocumentStatusBadgeComponent, type: :component do
  it "displays a gray badge for a draft document" do
    rendered = render_inline(described_class.new(status: "draft"))

    expect(rendered).to have_css("span.bg-gray-100", text: "Draft")
  end

  it "displays an info badge for an in-progress document" do
    rendered = render_inline(described_class.new(status: "in_progress"))

    expect(rendered).to have_css("span.bg-info-100", text: "In Progress")
  end

  it "displays a primary badge for a signed document" do
    rendered = render_inline(described_class.new(status: "signed"))

    expect(rendered).to have_css("span.bg-primary-100", text: "Signed")
  end

  it "displays a success badge for a finalized document" do
    rendered = render_inline(described_class.new(status: "finalized"))

    expect(rendered).to have_css("span.bg-success-100", text: "Finalized")
  end

  it "displays a danger badge for a cancelled document" do
    rendered = render_inline(described_class.new(status: "cancelled"))

    expect(rendered).to have_css("span.bg-danger-100", text: "Cancelled")
  end
end
