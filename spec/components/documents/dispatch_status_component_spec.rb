# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::DispatchStatusComponent, type: :component do
  let(:document) { create(:document) }
  let(:actor) { create(:user) }
  let(:contact_a) { create(:contact, entity: document.entity, first_name: "Jean", last_name: "Dupont") }
  let(:contact_b) { create(:contact, entity: document.entity, first_name: "Marie", last_name: "Petit") }

  let(:current_user) { document.created_by }

  subject { render_inline(described_class.new(document: document, current_user: current_user)) }

  context "when there are no dispatch events" do
    it "shows a not-dispatched-yet message" do
      expect(subject).to have_text("Not dispatched yet.")
    end
  end

  it "wraps its own output in the document's dispatch_status dom id, so a Turbo Stream replace keeps the id for later broadcasts" do
    expect(subject).to have_css("##{ActionView::RecordIdentifier.dom_id(document, :dispatch_status)}")
  end

  context "with a single queued recipient" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_queued",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email })
    end

    it "shows the recipient as pending" do
      expect(subject).to have_text("Jean Dupont")
      expect(subject).to have_text("Pending")
    end
  end

  context "with a recipient that was queued then sent" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_queued",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email },
        created_at: 1.minute.ago)
      create(:audit_log, auditable: document, user: actor, action: "dispatch_sent",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email })
    end

    it "shows the recipient's latest status: sent" do
      expect(subject).to have_text("Sent")
      expect(subject).not_to have_text("Pending")
    end
  end

  context "with a recipient whose delivery failed" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_queued",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email },
        created_at: 1.minute.ago)
      create(:audit_log, auditable: document, user: actor, action: "dispatch_failed",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email, "error" => "SMTP timeout" })
    end

    it "shows the recipient's latest status: failed" do
      expect(subject).to have_text("Failed")
    end
  end

  context "with two different recipients" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_sent",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email })
      create(:audit_log, auditable: document, user: actor, action: "dispatch_queued",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_b.id, "recipient_email" => contact_b.email })
    end

    it "lists both recipients with their own status" do
      expect(subject).to have_text("Jean Dupont")
      expect(subject).to have_text("Sent")
      expect(subject).to have_text("Marie Petit")
      expect(subject).to have_text("Pending")
    end
  end

  context "with an external recipient on a finalized document, viewed by its creator" do
    let(:document) { create(:document, :finalized, created_by: current_user) }
    let(:current_user) { create(:user) }

    before do
      create(:audit_log, auditable: document, user: current_user, action: "dispatch_sent",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email })
    end

    it "renders a Resend button for the recipient" do
      expect(subject).to have_button("Resend")
    end
  end

  context "with an internal recipient on a finalized document, viewed by its creator" do
    let(:document) { create(:document, :finalized, created_by: current_user) }
    let(:current_user) { create(:user) }
    let(:internal_recipient) { create(:user) }

    before do
      create(:audit_log, auditable: document, user: current_user, action: "dispatch_sent",
        change_data: { "recipient_type" => "User", "recipient_id" => internal_recipient.id, "recipient_email" => internal_recipient.email })
    end

    it "does not render a Resend button" do
      expect(subject).not_to have_button("Resend")
    end
  end

  context "with an external recipient on a finalized document, rendered without a current_user (e.g. a broadcast update)" do
    let(:document) { create(:document, :finalized) }

    subject { render_inline(described_class.new(document: document)) }

    before do
      create(:audit_log, auditable: document, user: document.created_by, action: "dispatch_sent",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email })
    end

    it "does not render a Resend button" do
      expect(subject).not_to have_button("Resend")
    end
  end

  context "with an external recipient on a finalized document, viewed by an unauthorized user" do
    let(:document) { create(:document, :finalized) }
    let(:current_user) { create(:user) }

    before do
      create(:audit_log, auditable: document, user: document.created_by, action: "dispatch_sent",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact_a.id, "recipient_email" => contact_a.email })
    end

    it "does not render a Resend button" do
      expect(subject).not_to have_button("Resend")
    end
  end
end
