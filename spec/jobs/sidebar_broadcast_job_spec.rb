# frozen_string_literal: true

require "rails_helper"

RSpec.describe SidebarBroadcastJob do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let!(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }
  let(:stream_name) { Turbo::StreamsChannel.send(:stream_name_from, [ entity, user, :sidebar ]) }

  describe "#perform" do
    it "broadcasts an update for the todo badge with the freshly computed count" do
      create(:document, :finalized, :expecting_response, entity: entity, addressee: user)

      expect {
        described_class.new.perform(user.id, entity.id)
      }.to have_broadcasted_to(stream_name).with { |content|
        expect(content).to match(%r{<turbo-stream action="update" target="sidebar-badge-todo">\s*<template>1</template>\s*</turbo-stream>})
      }
    end

    it "broadcasts updates for all eight sidebar badges in a single message" do
      expect {
        described_class.new.perform(user.id, entity.id)
      }.to have_broadcasted_to(stream_name).exactly(1).times.with { |content|
        %w[overview to_validate received mine todo waiting info incoming_mail].each do |key|
          expect(content).to include(%(target="sidebar-badge-#{key}"))
        end
      }
    end
  end
end
