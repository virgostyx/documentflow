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

  describe "#checked_out" do
    let(:mail) { described_class.checked_out(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.reference_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.reference_number, document.subject, document_url)
    end
  end

  describe "#checked_in" do
    let(:mail) { described_class.checked_in(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.reference_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.reference_number, document.subject, document_url)
    end
  end

  describe "#document_finalized" do
    let(:mail) { described_class.document_finalized(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("finalized", document.reference_number)
    end

    it "renders a text and an html part mentioning the document has been finalized and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.reference_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.reference_number, document.subject, document_url)
    end
  end

  describe "#document_addressed" do
    context "with an internal user recipient" do
      let(:mail) { described_class.document_addressed(user, document) }

      it "is addressed to the user with a subject mentioning the reference number" do
        expect(mail.to).to eq([ user.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part linking to the authenticated document page" do
        expect(mail.text_part.body.encoded).to include(user.display_name, document.reference_number, document.subject, document_url)
        expect(mail.html_part.body.encoded).to include(user.display_name, document.reference_number, document.subject, document_url)
      end

      it "does not mention any link expiration" do
        expect(mail.text_part.body.encoded).not_to include("expire")
        expect(mail.html_part.body.encoded).not_to include("expire")
      end
    end

    context "with an external contact recipient" do
      let(:contact) { create(:contact, entity: document.entity) }
      let(:mail) { described_class.document_addressed(contact, document) }

      it "is addressed to the contact with a subject mentioning the reference number" do
        expect(mail.to).to eq([ contact.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part linking to an unauthenticated shared link" do
        mail.message

        shared_link = document.shared_links.active.sole
        shared_url = Rails.application.routes.url_helpers.shared_document_url(
          shared_link.token, **Rails.application.config.action_mailer.default_url_options
        )

        expect(mail.text_part.body.encoded).to include(contact.display_name, document.reference_number, document.subject, shared_url)
        expect(mail.html_part.body.encoded).to include(contact.display_name, document.reference_number, document.subject, shared_url)
      end

      it "reuses an existing active shared link instead of creating a new one" do
        existing = create(:shared_link, document: document)

        expect { mail.deliver_now }.not_to change(SharedLink, :count)
        expect(mail.text_part.body.encoded).to include(existing.token)
      end

      it "mentions the shared link's expiration date" do
        mail.message

        expiry = I18n.l(document.shared_links.active.sole.expires_at)

        expect(mail.text_part.body.encoded).to include(expiry)
        expect(mail.html_part.body.encoded).to include(expiry)
      end
    end
  end

  describe "#cc_notification" do
    context "with an internal user recipient" do
      let(:mail) { described_class.cc_notification(user, document) }

      it "is addressed to the user with a subject mentioning the reference number" do
        expect(mail.to).to eq([ user.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part linking to the authenticated document page" do
        expect(mail.text_part.body.encoded).to include(user.display_name, document.reference_number, document.subject, document_url)
        expect(mail.html_part.body.encoded).to include(user.display_name, document.reference_number, document.subject, document_url)
      end

      it "does not mention any link expiration" do
        expect(mail.text_part.body.encoded).not_to include("expire")
        expect(mail.html_part.body.encoded).not_to include("expire")
      end
    end

    context "with an external contact recipient" do
      let(:contact) { create(:contact, entity: document.entity) }
      let(:mail) { described_class.cc_notification(contact, document) }

      it "is addressed to the contact with a subject mentioning the reference number" do
        expect(mail.to).to eq([ contact.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part linking to an unauthenticated shared link" do
        mail.message

        shared_link = document.shared_links.active.sole
        shared_url = Rails.application.routes.url_helpers.shared_document_url(
          shared_link.token, **Rails.application.config.action_mailer.default_url_options
        )

        expect(mail.text_part.body.encoded).to include(contact.display_name, document.reference_number, document.subject, shared_url)
        expect(mail.html_part.body.encoded).to include(contact.display_name, document.reference_number, document.subject, shared_url)
      end

      it "reuses an existing active shared link instead of creating a new one" do
        existing = create(:shared_link, document: document)

        expect { mail.deliver_now }.not_to change(SharedLink, :count)
        expect(mail.text_part.body.encoded).to include(existing.token)
      end

      it "mentions the shared link's expiration date" do
        mail.message

        expiry = I18n.l(document.shared_links.active.sole.expires_at)

        expect(mail.text_part.body.encoded).to include(expiry)
        expect(mail.html_part.body.encoded).to include(expiry)
      end
    end
  end
end
