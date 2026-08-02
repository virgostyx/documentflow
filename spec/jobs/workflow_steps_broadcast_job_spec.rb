# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowStepsBroadcastJob do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let!(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity) }
  let(:stream_name) { Turbo::StreamsChannel.send(:stream_name_from, [ entity, user, :workflow ]) }

  describe "#perform" do
    it "broadcasts a replace action targeting the document's workflow-steps dom id" do
      target = ActionView::RecordIdentifier.dom_id(document, :workflow_steps)

      expect {
        described_class.new.perform(user.id, document.id)
      }.to have_broadcasted_to(stream_name).with { |content|
        expect(content).to include(%(action="replace"))
        expect(content).to include(%(target="#{target}"))
      }
    end

    it "includes the rendered workflow steps card for the given viewer" do
      expect {
        described_class.new.perform(user.id, document.id)
      }.to have_broadcasted_to(stream_name).with { |content|
        expect(content).to include("RED")
        expect(content).to include("VISA")
      }
    end
  end
end
