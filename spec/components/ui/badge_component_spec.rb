# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::BadgeComponent, type: :component do
  it "renders the given content" do
    rendered = render_inline(described_class.new) { "Active" }

    expect(rendered).to have_css("span", text: "Active")
  end

  it "defaults to the gray color" do
    rendered = render_inline(described_class.new) { "Active" }

    expect(rendered).to have_css("span.bg-gray-100.text-gray-700")
  end

  it "applies the color-specific classes" do
    rendered = render_inline(described_class.new(color: :success)) { "Approved" }

    expect(rendered).to have_css("span.bg-success-100.text-success-700")
  end

  it "supports the primary color" do
    rendered = render_inline(described_class.new(color: :primary)) { "Owner" }

    expect(rendered).to have_css("span.bg-primary-100.text-primary-700")
  end

  it "falls back to gray for an unknown color" do
    rendered = render_inline(described_class.new(color: :unknown)) { "Mystery" }

    expect(rendered).to have_css("span.bg-gray-100.text-gray-700")
  end

  it "renders the given id when provided" do
    rendered = render_inline(described_class.new(id: "sidebar-badge-todo")) { "3" }

    expect(rendered).to have_css("span#sidebar-badge-todo")
  end

  it "renders no id attribute when none is given" do
    rendered = render_inline(described_class.new) { "Active" }

    expect(rendered.css("span").first["id"]).to be_nil
  end
end
