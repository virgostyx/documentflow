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

  describe "#mail_lead_assigned" do
    let(:mail) { described_class.mail_lead_assigned(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.reference_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.reference_number, document.subject, document_url)
    end
  end

  describe "#mail_action_assigned" do
    let(:mail) { described_class.mail_action_assigned(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "renders a text and an html part mentioning the document, the routing message, and linking to it" do
      document.update!(routing_message: "Please handle this by Friday")

      expect(mail.text_part.body.encoded).to include(document.reference_number, document.subject, document.routing_message, document_url)
      expect(mail.html_part.body.encoded).to include(document.reference_number, document.subject, document.routing_message, document_url)
    end
  end

  describe "#cc_notification" do
    let(:mail) { described_class.cc_notification("cc@example.com", "Jane Doe", document) }

    it "is addressed to the given recipient with a subject mentioning the reference number" do
      expect(mail.to).to eq([ "cc@example.com" ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "renders a text and an html part greeting the recipient and linking to the document" do
      expect(mail.text_part.body.encoded).to include("Jane Doe", document.reference_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include("Jane Doe", document.reference_number, document.subject, document_url)
    end
  end
end
