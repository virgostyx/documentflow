# frozen_string_literal: true

require "rails_helper"

RSpec.describe DepartmentPolicy, type: :policy do
  subject(:policy) { described_class.new(user, department) }

  let(:entity) { create(:entity) }
  let(:department) { build(:department, entity: entity) }

  let(:owner)  { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)  { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)  { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }
  let(:outsider) { create(:user) }

  describe "#index? / #show?" do
    context "as member"   do let(:user) { member };   it { is_expected.to permit_action(:index) } end
    context "as guest"    do let(:user) { guest };    it { is_expected.to permit_action(:index) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(:index) } end
  end

  describe "#create? / #update?" do
    context "as entity owner"  do let(:user) { owner };  it { is_expected.to permit_action(:create) } end
    context "as entity admin"  do let(:user) { admin };  it { is_expected.to permit_action(:create) } end
    context "as entity member" do let(:user) { member }; it { is_expected.not_to permit_action(:create) } end
    context "as entity guest"  do let(:user) { guest };  it { is_expected.not_to permit_action(:create) } end
  end

  describe "#destroy?" do
    context "as entity owner" do
      let(:user) { owner }

      context "when empty and not the default department" do
        let(:department) { create(:department, entity: entity) }
        it { is_expected.to permit_action(:destroy) }
      end

      context "when it is the default department" do
        let(:department) { create(:department, :default, entity: entity) }
        it { is_expected.not_to permit_action(:destroy) }
      end

      context "when it still has documents" do
        let(:department) { create(:department, entity: entity) }
        before { create(:document, entity: entity, department: department) }
        it { is_expected.not_to permit_action(:destroy) }
      end
    end

    context "as entity member" do
      let(:user) { member }
      let(:department) { create(:department, entity: entity) }
      it { is_expected.not_to permit_action(:destroy) }
    end
  end

  describe "Scope" do
    let!(:owned_department) { create(:department, entity: entity, name: "Owned department") }
    let!(:other_department) { create(:department, entity: create(:entity), name: "Other department") }

    it "only includes departments from entities the user belongs to" do
      result = DepartmentPolicy::Scope.new(member, Department).resolve

      expect(result).to include(owned_department)
      expect(result).not_to include(other_department)
    end
  end
end
