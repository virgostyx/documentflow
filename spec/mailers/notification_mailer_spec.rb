# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationMailer do
  let(:user) { create(:user) }
  let(:document) { create(:document) }
  let(:document_url) do
    Rails.application.routes.url_helpers.entity_document_url(
      document.entity, document, **Rails.application.config.action_mailer.default_url_options
    )
  end

  describe "#action_required" do
    let(:mail) { described_class.action_required(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.reference_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.reference_number, document.subject, document_url)
    end
  end

  describe "#rejection_alert" do
    let(:mail) { described_class.rejection_alert(user, document, "Pièce manquante") }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "renders a text and an html part with the rejection reason and a link to the document" do
      expect(mail.text_part.body.encoded).to include("Pièce manquante", document_url)
      expect(mail.html_part.body.encoded).to include("Pièce manquante", document_url)
    end
  end
end
