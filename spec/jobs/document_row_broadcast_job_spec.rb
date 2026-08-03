# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentRowBroadcastJob do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:other_department) { create(:department, entity: entity) }
  let(:document) { create(:document, :finalized, entity: entity, department: department) }

  let(:owner) { create(:user) }
  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }

  let(:department_member) { create(:user) }
  let!(:department_member_eu) do
    eu = create(:entity_user, entity: entity, user: department_member, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let(:other_department_member) { create(:user) }
  let!(:other_department_member_eu) do
    eu = create(:entity_user, entity: entity, user: other_department_member, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: other_department)
    eu
  end

  describe "#perform" do
    it "broadcasts a prepend action to the entity owner" do
      stream_name = Turbo::StreamsChannel.send(:stream_name_from, [ entity, owner, :documents ])

      expect {
        described_class.new.perform(document.id)
      }.to have_broadcasted_to(stream_name).with { |content|
        expect(content).to include(%(action="prepend"))
        expect(content).to include(%(target="#{DocumentRowBroadcastJob::TARGET_DOM_ID}"))
        expect(content).to include(document.subject)
      }
    end

    it "broadcasts to a member of the document's own department" do
      stream_name = Turbo::StreamsChannel.send(:stream_name_from, [ entity, department_member, :documents ])

      expect {
        described_class.new.perform(document.id)
      }.to have_broadcasted_to(stream_name)
    end

    it "does not broadcast to a member of a different department" do
      stream_name = Turbo::StreamsChannel.send(:stream_name_from, [ entity, other_department_member, :documents ])

      expect {
        described_class.new.perform(document.id)
      }.not_to have_broadcasted_to(stream_name)
    end
  end
end
