# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentPolicy, type: :policy do
  subject(:policy) { described_class.new(user, document) }

  let(:entity) { create(:entity) }

  let(:owner)    { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)    { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member)   { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)    { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }
  let(:outsider) { create(:user) }

  describe "#index?" do
    let(:document) { entity }

    context "as member" do let(:user) { member }; it { is_expected.to permit_action(:index) } end
    context "as guest"  do let(:user) { guest };  it { is_expected.to permit_action(:index) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(:index) } end
  end

  describe "#show?" do
    context "as outsider" do
      let(:document) { create(:document, entity: entity) }
      let(:user) { outsider }
      it { is_expected.not_to permit_action(:show) }
    end

    context "with department restrictions" do
      let(:department) { create(:department, entity: entity) }
      let(:other_department) { create(:department, entity: entity) }
      let(:document) { create(:document, entity: entity, department: department) }

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
          create(:entity_user_department, entity_user: eu, department: other_department)
        end
      end

      context "as a member of the document's department" do
        let(:user) { department_member }
        it { is_expected.to permit_action(:show) }
      end

      context "as a guest of the document's department" do
        let(:user) { department_guest }
        it { is_expected.to permit_action(:show) }
      end

      context "as a member of a different department" do
        let(:user) { other_department_member }
        it { is_expected.not_to permit_action(:show) }
      end

      context "as a member of a different department but assigned as a workflow step actor" do
        let(:user) { other_department_member }
        before { create(:workflow_step, document: document, actor: user) }
        it { is_expected.to permit_action(:show) }
      end

      context "as a member with no department assignment at all" do
        let(:user) { member }
        it { is_expected.not_to permit_action(:show) }
      end

      context "as entity owner" do let(:user) { owner }; it { is_expected.to permit_action(:show) } end
      context "as entity admin" do let(:user) { admin }; it { is_expected.to permit_action(:show) } end
    end
  end

  describe "#classify?" do
    let(:department) { create(:department, entity: entity) }
    let(:document) { create(:document, entity: entity, department: department) }

    let(:department_member) do
      create(:user).tap do |u|
        eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
        create(:entity_user_department, entity_user: eu, department: department)
      end
    end

    context "as outsider" do
      let(:user) { outsider }
      it { is_expected.not_to permit_action(:classify) }
    end

    context "as a member with no department assignment" do
      let(:user) { member }
      it { is_expected.not_to permit_action(:classify) }
    end

    context "as a member of the document's department" do
      let(:user) { department_member }
      it { is_expected.to permit_action(:classify) }
    end

    context "as entity owner" do let(:user) { owner }; it { is_expected.to permit_action(:classify) } end
    context "as entity admin" do let(:user) { admin }; it { is_expected.to permit_action(:classify) } end
  end

  describe "#create?" do
    let(:document) { entity }

    context "as member with a department" do
      let(:user) do
        create(:user).tap do |u|
          eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
          create(:entity_user_department, entity_user: eu, department: create(:department, entity: entity))
        end
      end

      it { is_expected.to permit_action(:create) }
    end

    context "as member without any department" do
      let(:user) { member }
      it { is_expected.not_to permit_action(:create) }
    end

    context "as entity owner without any department" do
      let(:user) { owner }
      it { is_expected.to permit_action(:create) }
    end

    context "as entity admin without any department" do
      let(:user) { admin }
      it { is_expected.to permit_action(:create) }
    end

    context "as guest" do let(:user) { guest }; it { is_expected.not_to permit_action(:create) } end
  end

  describe "#update?" do
    context "when the document is a draft" do
      let(:document) { create(:document, entity: entity, created_by: member) }

      context "as its author"     do let(:user) { member };   it { is_expected.to permit_action(:update) } end
      context "as entity owner"   do let(:user) { owner };    it { is_expected.to permit_action(:update) } end
      context "as entity admin"   do let(:user) { admin };    it { is_expected.to permit_action(:update) } end
      context "as another member" do let(:user) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }; it { is_expected.not_to permit_action(:update) } end
    end

    context "when the document is in_progress" do
      let(:document) do
        document = create(:document, :in_progress, entity: entity, created_by: member)
        create(:workflow_step, document: document, role: "VISA", order: 1, status: "pending", actor: admin)
        document
      end

      context "as the current step actor" do let(:user) { admin }; it { is_expected.to permit_action(:update) } end
      context "as the document author"    do let(:user) { member }; it { is_expected.not_to permit_action(:update) } end
    end

    context "when the document is finalized" do
      let(:document) { create(:document, :finalized, entity: entity, created_by: owner) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:update) } end
    end
  end

  describe "#check_out?" do
    context "when the document is a draft and not checked out" do
      let(:document) { create(:document, entity: entity, created_by: member) }

      context "as its author"     do let(:user) { member }; it { is_expected.to permit_action(:check_out) } end
      context "as entity owner"   do let(:user) { owner };  it { is_expected.to permit_action(:check_out) } end
      context "as another member" do let(:user) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }; it { is_expected.not_to permit_action(:check_out) } end
    end

    context "when the document is in_progress" do
      let(:document) do
        document = create(:document, :in_progress, entity: entity, created_by: member)
        create(:workflow_step, document: document, role: "VISA", order: 1, status: "pending", actor: admin)
        document
      end

      context "as the current step actor" do let(:user) { admin };  it { is_expected.to permit_action(:check_out) } end
      context "as the document author"    do let(:user) { member }; it { is_expected.not_to permit_action(:check_out) } end
    end

    context "when the document is already checked out by someone else" do
      let(:document) { create(:document, entity: entity, created_by: member, checked_out_by: admin, checked_out_at: Time.current) }

      context "as its author" do let(:user) { member }; it { is_expected.not_to permit_action(:check_out) } end
    end

    context "when the document is finalized" do
      let(:document) { create(:document, :finalized, entity: entity, created_by: owner) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:check_out) } end
    end
  end

  describe "#check_in?" do
    context "when checked out by the current user" do
      let(:document) { create(:document, entity: entity, created_by: member, checked_out_by: member, checked_out_at: Time.current) }

      context "as the checking-out user" do let(:user) { member }; it { is_expected.to permit_action(:check_in) } end
    end

    context "when checked out by someone else" do
      let(:document) { create(:document, entity: entity, created_by: member, checked_out_by: admin, checked_out_at: Time.current) }

      context "as another user with update rights" do let(:user) { member }; it { is_expected.not_to permit_action(:check_in) } end
    end

    context "when not checked out at all" do
      let(:document) { create(:document, entity: entity, created_by: member) }

      context "as its author" do let(:user) { member }; it { is_expected.not_to permit_action(:check_in) } end
    end
  end

  describe "#cancel_check_out?" do
    context "when checked out by the current user" do
      let(:document) { create(:document, entity: entity, created_by: member, checked_out_by: member, checked_out_at: Time.current) }

      context "as the checking-out user" do let(:user) { member }; it { is_expected.to permit_action(:cancel_check_out) } end
    end

    context "when checked out by someone else" do
      let(:document) { create(:document, entity: entity, created_by: member, checked_out_by: member, checked_out_at: Time.current) }

      context "as entity owner"   do let(:user) { owner }; it { is_expected.to permit_action(:cancel_check_out) } end
      context "as entity admin"   do let(:user) { admin }; it { is_expected.to permit_action(:cancel_check_out) } end
      context "as an unrelated member" do let(:user) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }; it { is_expected.not_to permit_action(:cancel_check_out) } end
    end

    context "when not checked out at all" do
      let(:document) { create(:document, entity: entity, created_by: member) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:cancel_check_out) } end
    end
  end

  describe "#destroy?" do
    let(:document) { create(:document, entity: entity, created_by: member) }

    context "as entity owner"  do let(:user) { owner };  it { is_expected.to permit_action(:destroy) } end
    context "as entity admin"  do let(:user) { admin };  it { is_expected.to permit_action(:destroy) } end
    context "as entity member" do let(:user) { member }; it { is_expected.not_to permit_action(:destroy) } end
  end

  describe "#launch?" do
    context "when the document is a draft" do
      let(:document) { create(:document, entity: entity, created_by: member) }

      context "as its author"   do let(:user) { member }; it { is_expected.to permit_action(:launch) } end
      context "as entity owner" do let(:user) { owner };  it { is_expected.to permit_action(:launch) } end
      context "as entity admin" do let(:user) { admin };  it { is_expected.to permit_action(:launch) } end
      context "as another member" do let(:user) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }; it { is_expected.not_to permit_action(:launch) } end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :in_progress, entity: entity, created_by: owner) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:launch) } end
    end
  end

  describe "#cancel?" do
    context "when the document is not finalized" do
      let(:document) { create(:document, entity: entity, created_by: member) }

      context "as its author"   do let(:user) { member }; it { is_expected.to permit_action(:cancel) } end
      context "as entity owner" do let(:user) { owner };  it { is_expected.to permit_action(:cancel) } end
      context "as an outsider"  do let(:user) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }; it { is_expected.not_to permit_action(:cancel) } end
    end

    context "when the document is finalized" do
      let(:document) { create(:document, :finalized, entity: entity, created_by: owner) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:cancel) } end
    end
  end

  describe "#approve?" do
    let(:document) do
      document = create(:document, :in_progress, entity: entity, created_by: member)
      create(:workflow_step, document: document, role: "VISA", order: 1, status: "pending", actor: admin)
      document
    end

    context "as the current step actor" do let(:user) { admin };  it { is_expected.to permit_action(:approve) } end
    context "as someone else"           do let(:user) { member }; it { is_expected.not_to permit_action(:approve) } end
  end

  describe "#reject?" do
    context "when the current step is not RED" do
      let(:document) do
        document = create(:document, :in_progress, entity: entity, created_by: member)
        create(:workflow_step, document: document, role: "VISA", order: 1, status: "pending", actor: admin)
        document
      end

      context "as the current step actor" do let(:user) { admin };  it { is_expected.to permit_action(:reject) } end
      context "as someone else"           do let(:user) { member }; it { is_expected.not_to permit_action(:reject) } end
    end

    context "when the current step is RED" do
      let(:document) do
        document = create(:document, :in_progress, entity: entity, created_by: member)
        create(:workflow_step, document: document, role: "RED", order: 1, status: "pending", actor: member)
        document
      end

      context "as the RED actor" do let(:user) { member }; it { is_expected.not_to permit_action(:reject) } end
    end
  end

  describe "#route?" do
    let(:department) { create(:department, entity: entity) }
    let(:lead) do
      create(:user).tap do |u|
        eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
        create(:entity_user_department, entity_user: eu, department: department)
      end
    end

    context "when the document has not been routed yet" do
      let(:document) { create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead) }

      context "as the lead" do let(:user) { lead }; it { is_expected.to permit_action(:route) } end
      context "as entity owner" do let(:user) { owner }; it { is_expected.to permit_action(:route) } end
      context "as entity admin" do let(:user) { admin }; it { is_expected.to permit_action(:route) } end
      context "as another department member" do
        let(:user) do
          create(:user).tap do |u|
            eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
            create(:entity_user_department, entity_user: eu, department: department)
          end
        end
        it { is_expected.not_to permit_action(:route) }
      end
    end

    context "when the document has already been routed" do
      let(:document) do
        create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead, routed_at: Time.current)
      end

      context "as the lead" do let(:user) { lead }; it { is_expected.not_to permit_action(:route) } end
      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:route) } end
    end

    context "when the document is outgoing" do
      let(:document) { create(:document, entity: entity, department: department, created_by: lead) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:route) } end
    end
  end

  describe "Scope" do
    let(:other_entity) { create(:entity) }
    let!(:document_in_entity)       { create(:document, entity: entity) }
    let!(:document_in_other_entity) { create(:document, entity: other_entity) }

    before do
      other_entity_membership = create(:entity_user, user: member, entity: other_entity, role: "member", status: "active")
      member_entity_user = EntityUser.find_by(user: member, entity: entity)
      create(:entity_user_department, entity_user: member_entity_user, department: document_in_entity.department)
      create(:entity_user_department, entity_user: other_entity_membership, department: document_in_other_entity.department)
    end

    it "returns documents from accessible entities only" do
      scope = Pundit.policy_scope(member, Document)
      expect(scope).to contain_exactly(document_in_entity, document_in_other_entity)
    end

    it "returns no documents for outsiders" do
      scope = Pundit.policy_scope(outsider, Document)
      expect(scope).to be_empty
    end

    context "department restriction" do
      let(:department_a) { create(:department, entity: entity) }
      let(:department_b) { create(:department, entity: entity) }
      let(:department_c) { create(:department, entity: entity) }

      let!(:document_a) { create(:document, entity: entity, department: department_a) }
      let!(:document_b) { create(:document, entity: entity, department: department_b) }
      let!(:document_c) { create(:document, entity: entity, department: department_c) }

      it "limits a single-department member to that department's documents" do
        single_department_member = create(:user).tap do |u|
          eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
          create(:entity_user_department, entity_user: eu, department: department_a)
        end

        scope = Pundit.policy_scope(single_department_member, Document)
        expect(scope).to contain_exactly(document_a)
      end

      it "grants a multi-department member visibility across all their departments, not others" do
        multi_department_member = create(:user).tap do |u|
          eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
          create(:entity_user_department, entity_user: eu, department: department_a)
          create(:entity_user_department, entity_user: eu, department: department_b)
        end

        scope = Pundit.policy_scope(multi_department_member, Document)
        expect(scope).to contain_exactly(document_a, document_b)
      end

      it "leaves owner/admin visibility unrestricted across all departments" do
        expect(Pundit.policy_scope(owner, Document)).to include(document_a, document_b, document_c)
        expect(Pundit.policy_scope(admin, Document)).to include(document_a, document_b, document_c)
      end

      it "returns nothing for a member with no department assignment" do
        departmentless_member = create(:user).tap do |u|
          create(:entity_user, user: u, entity: entity, role: "member", status: "active")
        end

        scope = Pundit.policy_scope(departmentless_member, Document)
        expect(scope).to be_empty
      end

      it "returns nothing for a guest with no department assignment" do
        scope = Pundit.policy_scope(guest, Document)
        expect(scope).to be_empty
      end
    end
  end
end
