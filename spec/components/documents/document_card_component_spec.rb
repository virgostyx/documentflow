# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::DocumentCardComponent, type: :component do
  let(:user) { create(:user) }
  let(:document) { create(:document, status: "draft", subject: "Supplier contract") }

  subject { render_inline(described_class.new(document: document, current_user: user)) }

  it "displays the document reference number" do
    expect(subject).to have_text(document.reference_number)
  end

  it "displays the document subject" do
    expect(subject).to have_text("Supplier contract")
  end

  it "displays a gray badge for a draft document" do
    expect(subject).to have_css("span.bg-gray-100", text: "Draft")
  end

  it "links to the document page" do
    expect(subject).to have_link(href: Rails.application.routes.url_helpers.entity_document_path(document.entity, document))
  end

  context "when the document is in progress" do
    let(:document) { create(:document, :in_progress) }

    it "displays an info badge" do
      expect(subject).to have_css("span.bg-info-100", text: "In Progress")
    end
  end

  context "when the document is finalized" do
    let(:document) { create(:document, :finalized) }

    it "displays a success badge" do
      expect(subject).to have_css("span.bg-success-100", text: "Finalized")
    end
  end

  context "when the document is cancelled" do
    let(:document) { create(:document, :cancelled) }

    it "displays a danger badge" do
      expect(subject).to have_css("span.bg-danger-100", text: "Cancelled")
    end
  end
end
