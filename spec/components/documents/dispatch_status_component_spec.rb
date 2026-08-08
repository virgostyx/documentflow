# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::DispatchStatusComponent, type: :component do
  let(:document) { create(:document) }
  let(:actor) { create(:user) }
  let(:contact_a) { create(:contact, entity: document.entity, first_name: "Jean", last_name: "Dupont") }
  let(:contact_b) { create(:contact, entity: document.entity, first_name: "Marie", last_name: "Petit") }

  subject { render_inline(described_class.new(document: document)) }

  context "when there are no dispatch events" do
    it "renders nothing" do
      expect(subject.to_html.strip).to be_empty
    end
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
end
