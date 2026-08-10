# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::ThreadComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }

  it "links an outgoing document in the chain to its show page" do
    original = create(:document, :finalized, entity: entity, department: department)
    reply = create(:document, :finalized, entity: entity, department: department, in_reply_to: original)
    rendered = render_inline(described_class.new(documents: [ original, reply ], current_document: original))

    expected_path = Rails.application.routes.url_helpers.entity_document_path(entity, reply)
    expect(rendered).to have_css("a[href='#{expected_path}']", text: reply.display_number)
  end

  it "links an incoming document in the chain to its incoming-mail show page" do
    original = create(:document, :finalized, entity: entity, department: department)
    incoming_reply = create(:document, :incoming, :routed, entity: entity, department: department, in_reply_to: original)
    rendered = render_inline(described_class.new(documents: [ original, incoming_reply ], current_document: original))

    expected_path = Rails.application.routes.url_helpers.entity_incoming_mail_path(entity, incoming_reply)
    expect(rendered).to have_css("a[href='#{expected_path}']", text: incoming_reply.display_number)
  end

  it "marks the current document instead of linking it" do
    original = create(:document, :finalized, entity: entity, department: department)
    rendered = render_inline(described_class.new(documents: [ original ], current_document: original))

    expect(rendered).to have_text("Current")
    expect(rendered).not_to have_css("a", text: original.display_number)
  end
end
