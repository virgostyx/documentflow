# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentTemplatePolicy, type: :policy do
  subject(:policy) { described_class.new(user, document_template) }

  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:document_template) { create(:document_template, entity: entity, created_by: creator) }
  let(:creator) { create(:user) }

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

  describe "#show?" do
    context "when the template is entity-wide (no department)" do
      context "as a member with no department assignment" do
        let(:user) { member }
        it { is_expected.to permit_action(:show) }
      end
    end

    context "when the template is restricted to a department" do
      let(:document_template) { create(:document_template, entity: entity, created_by: creator, department: department) }

      context "as a member of that department" do
        let(:user) { member }
        before { create(:entity_user_department, entity_user: EntityUser.find_by(user: member, entity: entity), department: department) }
        it { is_expected.to permit_action(:show) }
      end

      context "as a member of a different department" do
        let(:user) { member }
        before { create(:entity_user_department, entity_user: EntityUser.find_by(user: member, entity: entity), department: create(:department, entity: entity)) }
        it { is_expected.not_to permit_action(:show) }
      end

      context "as entity owner" do
        let(:user) { owner }
        it { is_expected.to permit_action(:show) }
      end
    end
  end

  describe "#create?" do
    context "as entity owner"  do let(:user) { owner };  it { is_expected.to permit_action(:create) } end
    context "as entity admin"  do let(:user) { admin };  it { is_expected.to permit_action(:create) } end
    context "as entity member" do let(:user) { member }; it { is_expected.to permit_action(:create) } end
    context "as entity guest"  do let(:user) { guest };  it { is_expected.not_to permit_action(:create) } end
    context "as outsider"      do let(:user) { outsider }; it { is_expected.not_to permit_action(:create) } end
  end

  describe "#update? / #destroy?" do
    context "as the creator" do
      let(:user) { creator }
      before { create(:entity_user, user: creator, entity: entity, role: "member", status: "active") }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:destroy) }
    end

    context "as entity owner (not the creator)" do
      let(:user) { owner }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:destroy) }
    end

    context "as entity admin (not the creator)" do
      let(:user) { admin }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:destroy) }
    end

    context "as a different member" do
      let(:user) { member }
      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
    end
  end

  describe "Scope" do
    let!(:entity_wide_template) { create(:document_template, entity: entity, created_by: creator, name: "Entity wide") }
    let!(:department_template) do
      create(:document_template, entity: entity, created_by: creator, department: department, name: "Dept scoped")
    end
    let!(:other_department_template) do
      create(:document_template, entity: entity, created_by: creator, department: create(:department, entity: entity), name: "Other dept")
    end
    let!(:other_entity_template) { create(:document_template, entity: create(:entity), created_by: creator, name: "Other entity") }

    it "gives owners every template in their entity" do
      result = DocumentTemplatePolicy::Scope.new(owner, DocumentTemplate).resolve

      expect(result).to contain_exactly(entity_wide_template, department_template, other_department_template)
    end

    it "gives members entity-wide templates plus templates from their own departments" do
      create(:entity_user_department, entity_user: EntityUser.find_by(user: member, entity: entity), department: department)

      result = DocumentTemplatePolicy::Scope.new(member, DocumentTemplate).resolve

      expect(result).to contain_exactly(entity_wide_template, department_template)
    end

    it "excludes templates from entities the user does not belong to" do
      result = DocumentTemplatePolicy::Scope.new(owner, DocumentTemplate).resolve

      expect(result).not_to include(other_entity_template)
    end
  end
end
