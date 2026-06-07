# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::ButtonComponent, type: :component do
  it "renders a link when href is given" do
    rendered = render_inline(described_class.new(href: "/documents/new")) { "New document" }

    expect(rendered).to have_link("New document", href: "/documents/new")
  end

  it "renders a submit button when no href is given" do
    rendered = render_inline(described_class.new) { "Save" }

    expect(rendered).to have_button("Save")
  end

  it "applies the primary variant classes by default" do
    rendered = render_inline(described_class.new) { "Save" }

    expect(rendered).to have_css("button.bg-primary-600")
  end

  it "applies the secondary variant classes" do
    rendered = render_inline(described_class.new(variant: :secondary)) { "Cancel" }

    expect(rendered).to have_css("button.bg-white.text-gray-700")
  end

  it "applies the danger variant classes" do
    rendered = render_inline(described_class.new(variant: :danger, href: "/documents/1", method: :delete)) { "Delete" }

    expect(rendered).to have_css("a.bg-danger-600", text: "Delete")
  end

  it "forwards html options such as data attributes" do
    rendered = render_inline(described_class.new(href: "/documents/1", method: :delete, data: { turbo_confirm: "Are you sure?" })) { "Delete" }

    expect(rendered).to have_css("a[data-turbo-confirm='Are you sure?'][data-turbo-method='delete']")
  end
end
