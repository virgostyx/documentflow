# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomingMails::RowComponent, type: :component do
  let(:entity) { create(:entity) }

  it "renders the document's subject, reference, sender, lead and a link to its show page" do
    document = create(:document, :incoming, :routed, entity: entity, subject: "Reply from Bruno")

    rendered = render_inline(described_class.new(document: document))

    expect(rendered).to have_css("tr##{ActionView::RecordIdentifier.dom_id(document)}")
    expect(rendered).to have_text(document.subject)
    expect(rendered).to have_text(document.reference_number)
    expect(rendered).to have_text(document.lead_user.display_name)
    expect(rendered).to have_css("a[href='#{Rails.application.routes.url_helpers.entity_incoming_mail_path(entity, document)}']")
  end
end
