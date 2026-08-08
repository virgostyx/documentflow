# frozen_string_literal: true

require "rails_helper"

RSpec.describe DispatchStatusBroadcastJob do
  let(:document) { create(:document) }
  let(:actor) { create(:user) }
  let(:contact) { create(:contact, entity: document.entity, first_name: "Jean", last_name: "Dupont") }
  let(:stream_name) { Turbo::StreamsChannel.send(:stream_name_from, [ document, :dispatch_status ]) }

  before do
    create(:audit_log, auditable: document, user: actor, action: "dispatch_sent",
      change_data: { "recipient_type" => "Contact", "recipient_id" => contact.id, "recipient_email" => contact.email })
  end

  describe "#perform" do
    it "broadcasts a replace action targeting the document's dispatch-status dom id" do
      target = ActionView::RecordIdentifier.dom_id(document, :dispatch_status)

      expect {
        described_class.new.perform(document.id)
      }.to have_broadcasted_to(stream_name).with { |content|
        expect(content).to include(%(action="replace"))
        expect(content).to include(%(target="#{target}"))
      }
    end

    it "includes the freshly rendered dispatch status for the document" do
      expect {
        described_class.new.perform(document.id)
      }.to have_broadcasted_to(stream_name).with { |content|
        expect(content).to include("Jean Dupont")
        expect(content).to include("Sent")
      }
    end
  end
end
