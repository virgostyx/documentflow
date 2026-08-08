# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::AuditLogListComponent, type: :component do
  let(:document) { create(:document) }
  let(:actor) { create(:user, email: "actor@example.com", first_name: "Alice", last_name: "Martin") }

  subject { render_inline(described_class.new(document: document)) }

  context "when the document has no audit logs" do
    it "renders nothing" do
      expect(subject.to_html.strip).to be_empty
    end
  end

  context "with a simple event (no extra data)" do
    before { create(:audit_log, auditable: document, user: actor, action: "launch") }

    it "shows the actor and a humanized description" do
      expect(subject).to have_text("Alice Martin")
      expect(subject).to have_text("launched the validation circuit")
    end
  end

  context "with an approve_step event" do
    before { create(:audit_log, auditable: document, user: actor, action: "approve_step", change_data: { "role" => "VISA" }) }

    it "mentions the step's role" do
      expect(subject).to have_text("approved the VISA step")
    end
  end

  context "with a reject_step event that has a reason" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "reject_step",
        change_data: { "role" => "SIGN", "reason" => "Missing signature" })
    end

    it "includes the role and the reason" do
      expect(subject).to have_text("rejected the SIGN step — “Missing signature”")
    end
  end

  context "with a reject_step event without a reason" do
    before { create(:audit_log, auditable: document, user: actor, action: "reject_step", change_data: { "role" => "VISA" }) }

    it "does not render a dangling reason" do
      expect(subject).to have_text("rejected the VISA step")
      expect(subject).not_to have_text("—")
    end
  end

  context "with a reassign_step event" do
    let(:previous_actor) { create(:user, first_name: "Bob", last_name: "Dupont") }
    let(:new_actor) { create(:user, first_name: "Carol", last_name: "Petit") }

    before do
      create(:audit_log, auditable: document, user: actor, action: "reassign_step",
        change_data: { "role" => "VISA", "previous_actor_id" => previous_actor.id, "new_actor_id" => new_actor.id })
    end

    it "names both the previous and the new actor" do
      expect(subject).to have_text("reassigned the VISA step from Bob Dupont to Carol Petit")
    end

    context "when the previous actor no longer exists" do
      before do
        create(:audit_log, auditable: document, user: actor, action: "reassign_step",
          change_data: { "role" => "SIGN", "previous_actor_id" => 0, "new_actor_id" => new_actor.id })
      end

      it "falls back to a generic label" do
        expect(subject).to have_text("a former member to Carol Petit")
      end
    end
  end

  context "with a classify event" do
    let(:node) { create(:classification_node, entity: document.entity, code: "3", name: "Contracts") }

    before { create(:audit_log, auditable: document, user: actor, action: "classify", change_data: { "classification_node_id" => node.id }) }

    it "names the classification node" do
      expect(subject).to have_text("changed the classification to 3 Contracts")
    end
  end

  context "with a classify event that unclassifies the document" do
    before { create(:audit_log, auditable: document, user: actor, action: "classify", change_data: { "classification_node_id" => nil }) }

    it "indicates the document was unclassified" do
      expect(subject).to have_text("changed the classification (unclassified)")
    end
  end

  context "with an apply_circuit_template event" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "apply_circuit_template",
        change_data: { "circuit_template_id" => 1, "steps_added" => 3 })
    end

    it "mentions the number of steps added" do
      expect(subject).to have_text("applied a circuit template (3 steps)")
    end
  end

  context "with check_out, check_in, cancel_check_out, finalize and route events" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "check_out")
      create(:audit_log, auditable: document, user: actor, action: "check_in")
      create(:audit_log, auditable: document, user: actor, action: "cancel_check_out")
      create(:audit_log, auditable: document, user: actor, action: "finalize")
      create(:audit_log, auditable: document, user: actor, action: "route")
    end

    it "renders a readable sentence for each" do
      expect(subject).to have_text("checked out the document")
      expect(subject).to have_text("checked in a new version")
      expect(subject).to have_text("released the checkout")
      expect(subject).to have_text("finalized the document")
      expect(subject).to have_text("routed the incoming mail")
    end
  end

  context "with a dispatch_queued event" do
    let(:contact) { create(:contact, entity: document.entity, first_name: "Jean", last_name: "Dupont") }

    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_queued",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact.id, "recipient_email" => contact.email })
    end

    it "names the recipient" do
      expect(subject).to have_text("queued the dispatch email to Jean Dupont")
    end
  end

  context "with a dispatch_sent event" do
    let(:contact) { create(:contact, entity: document.entity, first_name: "Jean", last_name: "Dupont") }

    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_sent",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact.id, "recipient_email" => contact.email })
    end

    it "names the recipient" do
      expect(subject).to have_text("sent the dispatch email to Jean Dupont")
    end
  end

  context "with a dispatch_failed event" do
    let(:contact) { create(:contact, entity: document.entity, first_name: "Jean", last_name: "Dupont") }

    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_failed",
        change_data: { "recipient_type" => "Contact", "recipient_id" => contact.id, "recipient_email" => contact.email, "error" => "SMTP timeout" })
    end

    it "names the recipient and the error" do
      expect(subject).to have_text("failed to send the dispatch email to Jean Dupont (SMTP timeout)")
    end
  end

  context "with a dispatch event whose recipient no longer exists" do
    before do
      create(:audit_log, auditable: document, user: actor, action: "dispatch_sent",
        change_data: { "recipient_type" => "Contact", "recipient_id" => 0, "recipient_email" => "old@example.com" })
    end

    it "falls back to the recorded email address" do
      expect(subject).to have_text("sent the dispatch email to old@example.com")
    end
  end

  context "with an unmapped action" do
    before { create(:audit_log, auditable: document, user: actor, action: "some_future_action") }

    it "falls back to a humanized version of the raw action" do
      expect(subject).to have_text("some future action")
    end
  end

  context "ordering" do
    let!(:older) { create(:audit_log, auditable: document, user: actor, action: "launch", created_at: 2.days.ago) }
    let!(:newer) { create(:audit_log, auditable: document, user: actor, action: "finalize", created_at: 1.hour.ago) }

    it "lists the most recent event first" do
      rows = subject.css("li").map(&:text)
      expect(rows.first).to include("finalized")
      expect(rows.last).to include("launched")
    end
  end
end
