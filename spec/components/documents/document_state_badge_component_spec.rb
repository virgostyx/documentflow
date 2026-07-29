# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::DocumentStateBadgeComponent, type: :component do
  it "delegates to the outgoing status badge for an outgoing document" do
    document = build(:document, :finalized)
    rendered = render_inline(described_class.new(document: document))

    expect(rendered).to have_css("span.bg-success-100", text: "Finalized")
  end

  it "displays an info badge for a routed incoming document" do
    document = build(:document, :incoming, :routed)
    rendered = render_inline(described_class.new(document: document))

    expect(rendered).to have_css("span.bg-info-100", text: "Incoming")
  end

  it "displays a gray badge for an incoming document that has not been routed yet" do
    document = build(:document, :incoming)
    rendered = render_inline(described_class.new(document: document))

    expect(rendered).to have_css("span.bg-gray-100", text: "Pending triage")
  end
end
