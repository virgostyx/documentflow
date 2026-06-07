# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::DefinitionListComponent, type: :component do
  it "renders each item as a term/description pair" do
    rendered = render_inline(described_class.new) do |dl|
      dl.with_item(term: "Status") { "Draft" }
      dl.with_item(term: "Sender") { "Acme Corp" }
    end

    expect(rendered).to have_css("dt", text: "Status")
    expect(rendered).to have_css("dd", text: "Draft")
    expect(rendered).to have_css("dt", text: "Sender")
    expect(rendered).to have_css("dd", text: "Acme Corp")
  end

  it "renders an optional badge next to the term" do
    rendered = render_inline(described_class.new) do |dl|
      dl.with_item(term: "Status", badge: { text: "Draft", color: :gray }) { "Draft" }
    end

    expect(rendered).to have_css("dt span.bg-gray-100", text: "Draft")
  end

  it "does not render a badge when none is given" do
    rendered = render_inline(described_class.new) do |dl|
      dl.with_item(term: "Sender") { "Acme Corp" }
    end

    expect(rendered).not_to have_css("dt span")
  end

  it "renders nothing when there are no items" do
    rendered = render_inline(described_class.new) { }

    expect(rendered).not_to have_css("dt")
    expect(rendered).not_to have_css("dd")
  end
end
