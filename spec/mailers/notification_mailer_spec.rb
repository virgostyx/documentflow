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
      expect(mail.subject).to include(document.display_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.display_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.display_number, document.subject, document_url)
    end
  end

  describe "#rejection_alert" do
    let(:mail) { described_class.rejection_alert(user, document, "Pièce manquante") }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.display_number)
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
      expect(mail.subject).to include(document.display_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.display_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.display_number, document.subject, document_url)
    end
  end

  describe "#mail_action_assigned" do
    let(:mail) { described_class.mail_action_assigned(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.display_number)
    end

    it "renders a text and an html part mentioning the document, the routing message, and linking to it" do
      document.update!(routing_message: "Please handle this by Friday")

      expect(mail.text_part.body.encoded).to include(document.display_number, document.subject, document.routing_message, document_url)
      expect(mail.html_part.body.encoded).to include(document.display_number, document.subject, document.routing_message, document_url)
    end
  end

  describe "#checked_out" do
    let(:mail) { described_class.checked_out(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.display_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.display_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.display_number, document.subject, document_url)
    end
  end

  describe "#checked_in" do
    let(:mail) { described_class.checked_in(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.display_number)
    end

    it "renders a text and an html part mentioning the document and linking to it" do
      expect(mail.text_part.body.encoded).to include(document.display_number, document.subject, document_url)
      expect(mail.html_part.body.encoded).to include(document.display_number, document.subject, document_url)
    end
  end

  describe "#document_finalized" do
    let(:document) { create(:document, :finalized) }
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
    let(:document) { create(:document, :finalized, dispatch_message: "Please review the attached document.") }

    context "with an internal user recipient" do
      let(:mail) { described_class.document_addressed(user, document) }

      it "is addressed to the user with a subject mentioning the reference number" do
        expect(mail.to).to eq([ user.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part with the dispatch message and a link to the authenticated document page" do
        expect(mail.text_part.body.encoded).to include(user.display_name, document.dispatch_message, document_url)
        expect(mail.html_part.body.encoded).to include(CGI.escapeHTML(user.display_name), document.dispatch_message, document_url)
      end

      it "does not mention any link expiration" do
        expect(mail.text_part.body.encoded).not_to include("expire")
        expect(mail.html_part.body.encoded).not_to include("expire")
      end

      it "renders the actor's edited message instead of the old static sentence" do
        document.update!(dispatch_message: "A custom note from the EXP actor.")

        expect(mail.text_part.body.encoded).to include("A custom note from the EXP actor.")
        expect(mail.text_part.body.encoded).not_to include("has been addressed to you and is now finalized")
      end

      it "substitutes the reserved {{recipient_name}} tag with this recipient's display name" do
        document.update!(dispatch_message: "Dear {{recipient_name}}, please review.")

        expect(mail.text_part.body.encoded).to include("Dear #{user.display_name}, please review.")
        expect(mail.text_part.body.encoded).not_to include("{{recipient_name}}")
      end

      it "uses the document's default subject when no dispatch_subject override is set" do
        expect(mail.subject).to eq("Document addressed to you: #{document.reference_number}")
      end

      it "uses the dispatch_subject override when set, substituting {{recipient_name}}" do
        document.update!(dispatch_subject: "Tender TND-2026-01 - {{recipient_name}}")

        expect(mail.subject).to eq("Tender TND-2026-01 - #{user.display_name}")
      end
    end

    context "with an external contact recipient" do
      let(:contact) { create(:contact, entity: document.entity) }
      let(:mail) { described_class.document_addressed(contact, document) }

      it "is addressed to the contact with a subject mentioning the reference number" do
        expect(mail.to).to eq([ contact.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part with the dispatch message and a link to an unauthenticated shared link" do
        mail.message

        shared_link = document.shared_links.active.sole
        shared_url = Rails.application.routes.url_helpers.shared_document_url(
          shared_link.token, **Rails.application.config.action_mailer.default_url_options
        )

        expect(mail.text_part.body.encoded).to include(contact.display_name, document.dispatch_message, shared_url)
        expect(mail.html_part.body.encoded).to include(CGI.escapeHTML(contact.display_name), document.dispatch_message, shared_url)
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

    context "with an external contact recipient and attachment dispatch enabled" do
      let(:document) { create(:document, :finalized, addressee_dispatch_as_attachment: true, dispatch_message: "Please review the attached document.") }
      let(:contact) { create(:contact, entity: document.entity) }
      let(:mail) { described_class.document_addressed(contact, document) }

      before do
        document.main_file.attach(io: StringIO.new("%PDF-1.4 main content"), filename: "main.pdf", content_type: "application/pdf")
      end

      it "attaches the main file instead of linking, and creates no shared link" do
        mail.message

        expect(mail.attachments.map(&:filename)).to eq([ "main.pdf" ])
        expect(document.shared_links.count).to eq(0)
      end

      it "mentions the attachment instead of a link, with no expiration" do
        expect(mail.text_part.body.encoded).to include("enclosed")
        expect(mail.html_part.body.encoded).to include("enclosed")
        expect(mail.text_part.body.encoded).not_to include("expire")
      end

      it "converts non-PDF annexes to PDF and disambiguates colliding filenames" do
        annex = create(:annex, document: document)
        annex.file.attach(io: StringIO.new("plain text"), filename: "main.docx", content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        converted_path = Rails.root.join("tmp", "annex-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(converted_path, "%PDF-1.4 converted content")
        allow(PdfConverter).to receive(:convert).and_return(converted_path)

        mail.message

        expect(mail.attachments.map(&:filename)).to contain_exactly("main.pdf", "main (2).pdf")
      end

      it "attaches an annex flagged skip_pdf_conversion in its original format, without converting it" do
        annex = create(:annex, document: document, skip_pdf_conversion: true)
        annex.file.attach(io: StringIO.new("plain text"), filename: "raw.docx", content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")

        expect(PdfConverter).not_to receive(:convert)

        mail.message

        expect(mail.attachments.map(&:filename)).to contain_exactly("main.pdf", "raw.docx")
        raw_attachment = mail.attachments.find { |a| a.filename == "raw.docx" }
        expect(raw_attachment.content_type).to start_with("application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        expect(raw_attachment.body.raw_source).to eq("plain text")
      end
    end

    context "with an external contact recipient, attachment dispatch enabled, and the attachment note disabled" do
      let(:document) do
        create(:document, :finalized, addressee_dispatch_as_attachment: true, include_attachment_note: false,
          dispatch_message: "Please review the attached document.")
      end
      let(:contact) { create(:contact, entity: document.entity) }
      let(:mail) { described_class.document_addressed(contact, document) }

      before do
        document.main_file.attach(io: StringIO.new("%PDF-1.4 main content"), filename: "main.pdf", content_type: "application/pdf")
      end

      it "does not mention the attachment note" do
        expect(mail.text_part.body.encoded).not_to include("enclosed")
        expect(mail.html_part.body.encoded).not_to include("enclosed")
      end
    end
  end

  describe "#cc_notification" do
    let(:document) { create(:document, :finalized, dispatch_message: "Please review the attached document.") }

    context "with an internal user recipient" do
      let(:mail) { described_class.cc_notification(user, document) }

      it "is addressed to the user with a subject mentioning the reference number" do
        expect(mail.to).to eq([ user.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part with the dispatch message and a link to the authenticated document page" do
        expect(mail.text_part.body.encoded).to include(user.display_name, document.dispatch_message, document_url)
        expect(mail.html_part.body.encoded).to include(CGI.escapeHTML(user.display_name), document.dispatch_message, document_url)
      end

      it "does not mention any link expiration" do
        expect(mail.text_part.body.encoded).not_to include("expire")
        expect(mail.html_part.body.encoded).not_to include("expire")
      end

      it "uses the document's default subject when no dispatch_subject override is set" do
        expect(mail.subject).to eq("Document finalized: #{document.reference_number}")
      end

      it "uses the dispatch_subject override when set, substituting {{recipient_name}}" do
        document.update!(dispatch_subject: "Tender TND-2026-01 - {{recipient_name}}")

        expect(mail.subject).to eq("Tender TND-2026-01 - #{user.display_name}")
      end
    end

    context "with an external contact recipient" do
      let(:contact) { create(:contact, entity: document.entity) }
      let(:mail) { described_class.cc_notification(contact, document) }

      it "is addressed to the contact with a subject mentioning the reference number" do
        expect(mail.to).to eq([ contact.email ])
        expect(mail.subject).to include(document.reference_number)
      end

      it "renders a text and an html part with the dispatch message and a link to an unauthenticated shared link" do
        mail.message

        shared_link = document.shared_links.active.sole
        shared_url = Rails.application.routes.url_helpers.shared_document_url(
          shared_link.token, **Rails.application.config.action_mailer.default_url_options
        )

        expect(mail.text_part.body.encoded).to include(contact.display_name, document.dispatch_message, shared_url)
        expect(mail.html_part.body.encoded).to include(CGI.escapeHTML(contact.display_name), document.dispatch_message, shared_url)
      end

      it "substitutes the reserved {{recipient_name}} tag with this recipient's own display name" do
        document.update!(dispatch_message: "Dear {{recipient_name}}, please submit your bid.")

        expect(mail.text_part.body.encoded).to include("Dear #{contact.display_name}, please submit your bid.")
        expect(mail.text_part.body.encoded).not_to include("{{recipient_name}}")
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

    context "with an external contact recipient whose cc_recipient has attachment dispatch enabled" do
      let(:contact) { create(:contact, entity: document.entity) }
      let!(:cc_recipient) { create(:cc_recipient, document: document, party: contact, dispatch_as_attachment: true) }
      let(:mail) { described_class.cc_notification(contact, document) }

      before do
        document.main_file.attach(io: StringIO.new("%PDF-1.4 main content"), filename: "main.pdf", content_type: "application/pdf")
      end

      it "attaches the main file instead of linking, and creates no shared link" do
        mail.message

        expect(mail.attachments.map(&:filename)).to eq([ "main.pdf" ])
        expect(document.shared_links.count).to eq(0)
      end
    end

    context "with an external contact recipient whose cc_recipient has attachment dispatch disabled" do
      let(:contact) { create(:contact, entity: document.entity) }
      let!(:cc_recipient) { create(:cc_recipient, document: document, party: contact, dispatch_as_attachment: false) }
      let(:mail) { described_class.cc_notification(contact, document) }

      it "still links to the shared link" do
        mail.message

        expect(mail.attachments).to be_empty
        expect(document.shared_links.count).to eq(1)
      end
    end
  end
end
