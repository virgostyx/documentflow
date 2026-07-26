# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::ActionsMenuComponent, type: :component do
  it "renders nothing when there are no items" do
    rendered = render_inline(described_class.new)

    expect(rendered.css("summary")).to be_empty
  end

  it "renders a summary labeled 'Actions' by default" do
    rendered = render_inline(described_class.new) do |menu|
      menu.with_item(href: "/documents/1/edit") { "Edit" }
    end

    expect(rendered).to have_css("summary", text: "Actions")
  end

  it "accepts a custom label" do
    rendered = render_inline(described_class.new(label: "Options")) do |menu|
      menu.with_item(href: "/documents/1/edit") { "Edit" }
    end

    expect(rendered).to have_css("summary", text: "Options")
  end

  it "renders each item as a link inside the menu" do
    rendered = render_inline(described_class.new) do |menu|
      menu.with_item(href: "/documents/1/edit") { "Edit" }
      menu.with_item(href: "/documents/1", method: :delete, variant: :danger) { "Delete" }
    end

    expect(rendered).to have_link("Edit", href: "/documents/1/edit", visible: false)
    expect(rendered).to have_link("Delete", href: "/documents/1", visible: false)
    expect(rendered).to have_css("a[role='menuitem'][data-turbo-method='delete']", text: "Delete", visible: false)
  end

  it "applies the danger variant classes to an item" do
    rendered = render_inline(described_class.new) do |menu|
      menu.with_item(href: "/documents/1", variant: :danger) { "Delete" }
    end

    expect(rendered).to have_css("a.text-danger-600", text: "Delete", visible: false)
  end

  it "forwards html options such as data attributes to an item" do
    rendered = render_inline(described_class.new) do |menu|
      menu.with_item(href: "/documents/1", data: { turbo_confirm: "Are you sure?" }) { "Delete" }
    end

    expect(rendered).to have_css("a[data-turbo-confirm='Are you sure?']", visible: false)
  end
end
