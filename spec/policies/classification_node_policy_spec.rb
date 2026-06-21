# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClassificationNodePolicy, type: :policy do
  subject(:policy) { described_class.new(user, node) }

  let(:entity) { create(:entity) }
  let(:node) { create(:classification_node, entity: entity, code: "1", name: "Administration") }

  let(:owner)    { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)    { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member)   { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)    { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }
  let(:outsider) { create(:user) }

  shared_examples "owner/admin only permission" do |action|
    context "as entity owner" do let(:user) { owner }; it { is_expected.to permit_action(action) } end
    context "as entity admin" do let(:user) { admin }; it { is_expected.to permit_action(action) } end
    context "as a regular member" do let(:user) { member }; it { is_expected.not_to permit_action(action) } end
    context "as a guest" do let(:user) { guest }; it { is_expected.not_to permit_action(action) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(action) } end
  end

  describe "#create?" do
    include_examples "owner/admin only permission", :create
  end

  describe "#update?" do
    include_examples "owner/admin only permission", :update
  end

  describe "#destroy?" do
    include_examples "owner/admin only permission", :destroy
  end

  describe "Scope" do
    let(:other_entity) { create(:entity) }

    let!(:node_a) { create(:classification_node, entity: entity, code: "1", name: "Administration") }
    let!(:node_b) { create(:classification_node, entity: entity, code: "2", name: "Finance") }
    let!(:node_in_other_entity) { create(:classification_node, entity: other_entity, code: "1", name: "Other entity root") }

    it "lets any active staff or guest member see every node entity-wide" do
      expect(Pundit.policy_scope(member, ClassificationNode)).to contain_exactly(node_a, node_b)
      expect(Pundit.policy_scope(guest, ClassificationNode)).to contain_exactly(node_a, node_b)
      expect(Pundit.policy_scope(owner, ClassificationNode)).to contain_exactly(node_a, node_b)
    end

    it "returns nothing for an outsider" do
      expect(Pundit.policy_scope(outsider, ClassificationNode)).to be_empty
    end
  end
end
