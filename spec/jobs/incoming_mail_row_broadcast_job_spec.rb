# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomingMailRowBroadcastJob do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :incoming, :routed, entity: entity, subject: "Reply from Bruno") }

  describe "#perform" do
    it "broadcasts a prepend action to the document's lead_user" do
      stream_name = Turbo::StreamsChannel.send(:stream_name_from, [ entity, document.lead_user, :documents ])

      expect {
        described_class.new.perform(document.id)
      }.to have_broadcasted_to(stream_name).with { |content|
        expect(content).to include(%(action="prepend"))
        expect(content).to include(%(target="#{described_class::TARGET_DOM_ID}"))
        expect(content).to include(document.subject)
      }
    end

    it "does not raise when the document has no lead_user" do
      document.update_column(:lead_user_id, nil)

      expect { described_class.new.perform(document.id) }.not_to raise_error
    end
  end
end
