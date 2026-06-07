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
    let(:document) { create(:document, entity: entity) }

    context "as member" do let(:user) { member }; it { is_expected.to permit_action(:show) } end
    context "as guest"  do let(:user) { guest };  it { is_expected.to permit_action(:show) } end
    context "as outsider" do let(:user) { outsider }; it { is_expected.not_to permit_action(:show) } end
  end

  describe "#create?" do
    let(:document) { entity }

    context "as member" do let(:user) { member }; it { is_expected.to permit_action(:create) } end
    context "as guest"  do let(:user) { guest };  it { is_expected.not_to permit_action(:create) } end
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

  describe "Scope" do
    let(:other_entity) { create(:entity) }
    let!(:document_in_entity)       { create(:document, entity: entity) }
    let!(:document_in_other_entity) { create(:document, entity: other_entity) }

    before { create(:entity_user, user: member, entity: other_entity, role: "member", status: "active") }

    it "returns documents from accessible entities only" do
      scope = Pundit.policy_scope(member, Document)
      expect(scope).to contain_exactly(document_in_entity, document_in_other_entity)
    end

    it "returns no documents for outsiders" do
      scope = Pundit.policy_scope(outsider, Document)
      expect(scope).to be_empty
    end
  end
end
