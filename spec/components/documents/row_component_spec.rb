# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::RowComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:user) { create(:user) }

  it "renders the document's subject, reference and a link to its show page" do
    document = create(:document, :finalized, entity: entity, department: department)
    rendered = render_inline(described_class.new(document: document, current_user: user))

    expect(rendered).to have_css("tr##{ActionView::RecordIdentifier.dom_id(document)}")
    expect(rendered).to have_text(document.subject)
    expect(rendered).to have_text(document.reference_number)
    expect(rendered).to have_css("a[href='#{Rails.application.routes.url_helpers.entity_document_path(entity, document)}']")
  end

  it "shows a Provisional badge when the document has no reference_number yet" do
    document = create(:document, entity: entity, department: department)
    rendered = render_inline(described_class.new(document: document, current_user: user))

    expect(rendered).to have_text("Provisional")
  end

  it "links to the incoming-mail show page for an incoming document" do
    document = create(:document, :incoming, :routed, entity: entity)
    rendered = render_inline(described_class.new(document: document, current_user: user))

    expected_path = Rails.application.routes.url_helpers.entity_incoming_mail_path(entity, document)
    expect(rendered).to have_css("[data-row-link-url-value='#{expected_path}']")
  end

  it "shows a preview link only when the main_file is attached" do
    document = create(:document, :finalized, entity: entity, department: department)
    rendered = render_inline(described_class.new(document: document, current_user: user))
    expect(rendered).not_to have_css("a[title='Preview main document']")

    document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf")
    rendered = render_inline(described_class.new(document: document, current_user: user))
    expect(rendered).to have_css("a[title='Preview main document']")
  end

  it "shows a Reply button only when the current user is awaiting a response" do
    create(:entity_user, entity: entity, user: user, status: "active")
    document = create(:document, :finalized, :expecting_response, entity: entity, department: department, addressee: user)
    rendered = render_inline(described_class.new(document: document, current_user: user))

    expect(rendered).to have_link("Reply")
  end

  it "does not show a Reply button for an uninvolved viewer" do
    document = create(:document, :finalized, :expecting_response, entity: entity, department: department)
    rendered = render_inline(described_class.new(document: document, current_user: user))

    expect(rendered).not_to have_link("Reply")
  end
end
