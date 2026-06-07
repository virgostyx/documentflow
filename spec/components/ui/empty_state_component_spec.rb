# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::EmptyStateComponent, type: :component do
  it "displays the title" do
    rendered = render_inline(described_class.new(title: "No documents yet"))

    expect(rendered).to have_css("h3", text: "No documents yet")
  end

  it "displays the description when given" do
    rendered = render_inline(described_class.new(title: "No documents yet", description: "Create your first document to get started."))

    expect(rendered).to have_text("Create your first document to get started.")
  end

  it "renders the action slot when given" do
    rendered = render_inline(described_class.new(title: "No documents yet")) do |empty_state|
      empty_state.with_action { "<a href='/documents/new'>New document</a>".html_safe }
    end

    expect(rendered).to have_link("New document", href: "/documents/new")
  end
end
