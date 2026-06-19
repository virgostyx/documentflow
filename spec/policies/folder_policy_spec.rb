# frozen_string_literal: true

require "rails_helper"

RSpec.describe FolderPolicy, type: :policy do
  subject(:policy) { described_class.new(user, folder) }

  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:folder) { create(:folder, entity: entity, department: department) }

  let(:owner)    { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)    { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member)   { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)    { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }
  let(:outsider) { create(:user) }

  let(:department_member) do
    create(:user).tap do |u|
      eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
      create(:entity_user_department, entity_user: eu, department: department)
    end
  end

  let(:department_guest) do
    create(:user).tap do |u|
      eu = create(:entity_user, :guest, user: u, entity: entity, status: "active")
      create(:entity_user_department, entity_user: eu, department: department)
    end
  end

  let(:other_department_member) do
    create(:user).tap do |u|
      eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
      create(:entity_user_department, entity_user: eu, department: create(:department, entity: entity))
    end
  end

  shared_examples "department accessible permission" do |action|
    context "as entity owner" do let(:user) { owner }; it { is_expected.to permit_action(action) } end
    context "as entity admin" do let(:user) { admin }; it { is_expected.to permit_action(action) } end
    context "as a member of the folder's department" do let(:user) { department_member }; it { is_expected.to permit_action(action) } end
    context "as a guest of the folder's department" do let(:user) { department_guest }; it { is_expected.to permit_action(action) } end
    context "as a member of a different department" do let(:user) { other_department_member }; it { is_expected.not_to permit_action(action) } end
    context "as a member with no department assignment" do let(:user) { member }; it { is_expected.not_to permit_action(action) } end
    context "as a guest with no department assignment" do let(:user) { guest }; it { is_expected.not_to permit_action(action) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(action) } end
  end

  describe "#create?" do
    include_examples "department accessible permission", :create
  end

  describe "#update?" do
    include_examples "department accessible permission", :update
  end

  describe "#destroy?" do
    include_examples "department accessible permission", :destroy
  end

  describe "Scope" do
    let(:other_entity) { create(:entity) }
    let(:department_a) { create(:department, entity: entity) }
    let(:department_b) { create(:department, entity: entity) }

    let!(:folder_a) { create(:folder, entity: entity, department: department_a) }
    let!(:folder_b) { create(:folder, entity: entity, department: department_b) }
    let!(:folder_in_other_entity) { create(:folder, entity: other_entity, department: create(:department, entity: other_entity)) }

    it "leaves owner/admin visibility unrestricted across all departments" do
      expect(Pundit.policy_scope(owner, Folder)).to include(folder_a, folder_b)
      expect(Pundit.policy_scope(admin, Folder)).to include(folder_a, folder_b)
    end

    it "limits a single-department member to that department's folders" do
      single_department_member = create(:user).tap do |u|
        eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
        create(:entity_user_department, entity_user: eu, department: department_a)
      end

      scope = Pundit.policy_scope(single_department_member, Folder)
      expect(scope).to contain_exactly(folder_a)
    end

    it "returns nothing for a member with no department assignment" do
      departmentless_member = create(:user).tap do |u|
        create(:entity_user, user: u, entity: entity, role: "member", status: "active")
      end

      scope = Pundit.policy_scope(departmentless_member, Folder)
      expect(scope).to be_empty
    end

    it "returns no folders for outsiders" do
      scope = Pundit.policy_scope(outsider, Folder)
      expect(scope).to be_empty
    end
  end
end
