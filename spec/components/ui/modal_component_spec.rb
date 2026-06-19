# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::ModalComponent, type: :component do
  it "renders a dialog element" do
    rendered = render_inline(described_class.new)

    expect(rendered).to have_css("dialog[data-modal-target='dialog']")
  end

  it "wraps an empty turbo frame with the default id" do
    rendered = render_inline(described_class.new)

    expect(rendered).to have_css("dialog turbo-frame#modal")
  end

  it "supports a custom frame id" do
    rendered = render_inline(described_class.new(id: "custom_modal"))

    expect(rendered).to have_css("dialog turbo-frame#custom_modal")
  end
end
