# frozen_string_literal: true

require "rails_helper"

RSpec.describe CircuitTemplatePolicy, type: :policy do
  subject(:policy) { described_class.new(user, circuit_template) }

  let(:entity) { create(:entity) }
  let(:circuit_template) { build(:circuit_template, entity: entity) }

  let(:owner)  { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)  { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)  { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }

  CIRCUIT_TEMPLATE_ACTIONS = %i[index create update destroy].freeze

  context "as entity owner" do
    let(:user) { owner }

    it "permits managing circuit templates" do
      CIRCUIT_TEMPLATE_ACTIONS.each { |action| expect(policy).to permit_action(action) }
    end
  end

  context "as entity admin" do
    let(:user) { admin }

    it "permits managing circuit templates" do
      CIRCUIT_TEMPLATE_ACTIONS.each { |action| expect(policy).to permit_action(action) }
    end
  end

  context "as a regular member" do
    let(:user) { member }

    it "does not permit managing circuit templates" do
      CIRCUIT_TEMPLATE_ACTIONS.each { |action| expect(policy).not_to permit_action(action) }
    end
  end

  context "as a guest" do
    let(:user) { guest }

    it "does not permit managing circuit templates" do
      CIRCUIT_TEMPLATE_ACTIONS.each { |action| expect(policy).not_to permit_action(action) }
    end
  end

  describe "Scope" do
    let!(:owned_template) { create(:circuit_template, entity: entity, name: "Owned circuit") }
    let!(:other_template) { create(:circuit_template, name: "Other circuit") }

    it "only includes circuit templates from entities the user manages" do
      result = CircuitTemplatePolicy::Scope.new(owner, CircuitTemplate).resolve

      expect(result).to include(owned_template)
      expect(result).not_to include(other_template)
    end
  end
end
