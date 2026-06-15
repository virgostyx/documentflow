# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::BreadcrumbsComponent, type: :component do
  let(:items) do
    [
      { label: "Documents", path: "/entities/1/documents" },
      { label: "My documents", path: "/entities/1/documents/mine" },
      { label: "Overview" }
    ]
  end

  before { render_inline(described_class.new(items: items)) }

  it "renders each breadcrumb label" do
    expect(page).to have_text("Documents")
    expect(page).to have_text("My documents")
    expect(page).to have_text("Overview")
  end

  it "renders links for items with a path" do
    expect(page).to have_link("Documents", href: "/entities/1/documents")
    expect(page).to have_link("My documents", href: "/entities/1/documents/mine")
  end

  it "renders the last item as plain text (no link)" do
    expect(page).not_to have_link("Overview")
    expect(page).to have_css("span", text: "Overview")
  end

  it "renders chevron separators between items" do
    expect(page).to have_css("svg", minimum: 2)
  end

  it "renders nothing when items are empty" do
    rendered = render_inline(described_class.new(items: []))

    expect(rendered).to have_no_css("nav")
  end
end
