# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContactPolicy, type: :policy do
  subject(:policy) { described_class.new(user, contact) }

  let(:entity) { create(:entity) }
  let(:contact) { create(:contact, entity: entity) }

  let(:owner)    { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)    { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member)   { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)    { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }
  let(:outsider) { create(:user) }

  describe "#index?" do
    context "as member"   do let(:user) { member };   it { is_expected.to permit_action(:index) } end
    context "as guest"    do let(:user) { guest };    it { is_expected.to permit_action(:index) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(:index) } end
  end

  shared_examples "staff only permission" do |action|
    context "as entity owner" do let(:user) { owner }; it { is_expected.to permit_action(action) } end
    context "as entity admin" do let(:user) { admin }; it { is_expected.to permit_action(action) } end
    context "as a regular member" do let(:user) { member }; it { is_expected.to permit_action(action) } end
    context "as a guest" do let(:user) { guest }; it { is_expected.not_to permit_action(action) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(action) } end
  end

  describe "#create?" do
    include_examples "staff only permission", :create
  end

  describe "#update?" do
    include_examples "staff only permission", :update
  end

  describe "#destroy?" do
    include_examples "staff only permission", :destroy
  end

  describe "Scope" do
    let(:other_entity) { create(:entity) }

    let!(:contact_a) { create(:contact, entity: entity) }
    let!(:contact_b) { create(:contact, entity: entity) }
    let!(:contact_in_other_entity) { create(:contact, entity: other_entity) }

    it "lets any active member see every contact entity-wide, regardless of role" do
      expect(Pundit.policy_scope(member, Contact)).to contain_exactly(contact_a, contact_b)
      expect(Pundit.policy_scope(guest, Contact)).to contain_exactly(contact_a, contact_b)
      expect(Pundit.policy_scope(owner, Contact)).to contain_exactly(contact_a, contact_b)
    end

    it "returns nothing for an outsider" do
      expect(Pundit.policy_scope(outsider, Contact)).to be_empty
    end
  end
end
