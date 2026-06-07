# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::MetadataComponent, type: :component do
  let(:document) { create(:document, document_date: Date.new(2026, 1, 15)) }

  subject { render_inline(described_class.new(document: document)) }

  it "displays the sender's name" do
    expect(subject).to have_text(document.sender.full_name)
  end

  it "displays the addressee's name" do
    expect(subject).to have_text(document.addressee.full_name)
  end

  it "displays the document date" do
    expect(subject).to have_text(I18n.l(document.document_date))
  end
end
