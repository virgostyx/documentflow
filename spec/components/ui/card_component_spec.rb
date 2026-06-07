# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::CardComponent, type: :component do
  it "renders the default content inside a card" do
    rendered = render_inline(described_class.new) { "Card body" }

    expect(rendered).to have_css("div.bg-white.rounded-lg", text: "Card body")
  end

  it "renders the header slot in a bordered header area" do
    rendered = render_inline(described_class.new) do |card|
      card.with_header { "Card title" }
      "Card body"
    end

    expect(rendered).to have_css("div.border-b", text: "Card title")
    expect(rendered).to have_text("Card body")
  end

  it "renders the footer slot in a bordered footer area" do
    rendered = render_inline(described_class.new) do |card|
      card.with_footer { "Card footer" }
      "Card body"
    end

    expect(rendered).to have_css("div.border-t", text: "Card footer")
  end

  it "does not render header or footer areas when no slot is given" do
    rendered = render_inline(described_class.new) { "Card body" }

    expect(rendered).not_to have_css("div.border-b")
    expect(rendered).not_to have_css("div.border-t")
  end
end
