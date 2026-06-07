# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::PageHeaderComponent, type: :component do
  it "displays the title" do
    rendered = render_inline(described_class.new(title: "Documents"))

    expect(rendered).to have_css("h1", text: "Documents")
  end

  it "displays the description when given" do
    rendered = render_inline(described_class.new(title: "Documents", description: "All entity documents"))

    expect(rendered).to have_text("All entity documents")
  end

  it "does not display a description block when none is given" do
    rendered = render_inline(described_class.new(title: "Documents"))

    expect(rendered).not_to have_css("p")
  end

  it "displays a back link when back_path is given" do
    rendered = render_inline(described_class.new(title: "Documents", back_path: "/dashboard", back_text: "Back to dashboard"))

    expect(rendered).to have_link("Back to dashboard", href: "/dashboard")
  end

  it "does not display a back link when back_path is absent" do
    rendered = render_inline(described_class.new(title: "Documents"))

    expect(rendered).not_to have_css("a")
  end
end
