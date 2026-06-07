# frozen_string_literal: true

require "rails_helper"

RSpec.describe EntityPolicy, type: :policy do
  subject(:policy) { described_class.new(user, entity) }

  let(:entity) { create(:entity) }

  let(:owner)    { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)    { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member)   { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)    { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }
  let(:outsider) { create(:user) }

  describe "#show?" do
    context "as owner"    do let(:user) { owner };    it { is_expected.to permit_action(:show) } end
    context "as admin"    do let(:user) { admin };    it { is_expected.to permit_action(:show) } end
    context "as member"   do let(:user) { member };   it { is_expected.to permit_action(:show) } end
    context "as guest"    do let(:user) { guest };    it { is_expected.to permit_action(:show) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(:show) } end
  end

  describe "#update?" do
    context "as owner"  do let(:user) { owner };  it { is_expected.to permit_action(:update) } end
    context "as admin"  do let(:user) { admin };  it { is_expected.to permit_action(:update) } end
    context "as member" do let(:user) { member }; it { is_expected.not_to permit_action(:update) } end
    context "as guest"  do let(:user) { guest };  it { is_expected.not_to permit_action(:update) } end
  end

  describe "#destroy?" do
    context "as owner"  do let(:user) { owner };  it { is_expected.to permit_action(:destroy) } end
    context "as admin"  do let(:user) { admin };  it { is_expected.not_to permit_action(:destroy) } end
    context "as member" do let(:user) { member }; it { is_expected.not_to permit_action(:destroy) } end
  end

  describe "#manage_members?" do
    context "as owner"  do let(:user) { owner };  it { is_expected.to permit_action(:manage_members) } end
    context "as admin"  do let(:user) { admin };  it { is_expected.to permit_action(:manage_members) } end
    context "as member" do let(:user) { member }; it { is_expected.not_to permit_action(:manage_members) } end
  end

  describe "Scope" do
    let(:other_entity) { create(:entity) }

    before { create(:entity_user, :owner, user: owner, entity: other_entity, status: "active") }

    it "returns entities the user belongs to" do
      scope = Pundit.policy_scope(owner, Entity)
      expect(scope).to contain_exactly(entity, other_entity)
    end

    it "returns no entities for outsiders" do
      scope = Pundit.policy_scope(outsider, Entity)
      expect(scope).to be_empty
    end
  end
end
