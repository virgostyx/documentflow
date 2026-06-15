# frozen_string_literal: true

require "rails_helper"

RSpec.describe CcRecipientPolicy, type: :policy do
  subject(:policy) { described_class.new(user, cc_recipient) }

  let(:entity) { create(:entity) }

  let(:owner)  { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }
  let(:admin)  { create(:user).tap { |u| create(:entity_user, :admin, user: u, entity: entity, status: "active") } }
  let(:member) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }
  let(:guest)  { create(:user).tap { |u| create(:entity_user, :guest, user: u, entity: entity, status: "active") } }
  let(:author) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }

  describe "#create?" do
    context "when the document is a draft" do
      let(:document) { create(:document, entity: entity, created_by: author) }
      let(:cc_recipient) { build(:cc_recipient, document: document) }

      context "as the document's author" do let(:user) { author }; it { is_expected.to permit_action(:create) } end
      context "as entity owner"        do let(:user) { owner };  it { is_expected.to permit_action(:create) } end
      context "as entity admin"        do let(:user) { admin };  it { is_expected.to permit_action(:create) } end
      context "as another member"      do let(:user) { member }; it { is_expected.not_to permit_action(:create) } end
      context "as entity guest"        do let(:user) { guest };  it { is_expected.not_to permit_action(:create) } end
    end

    context "when the document is finalized" do
      let(:document) { create(:document, :finalized, entity: entity, created_by: author) }
      let(:cc_recipient) { build(:cc_recipient, document: document) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:create) } end
    end
  end

  describe "#destroy?" do
    context "when the document is a draft" do
      let(:document) { create(:document, entity: entity, created_by: author) }
      let(:cc_recipient) { create(:cc_recipient, document: document) }

      context "as the document's author" do let(:user) { author }; it { is_expected.to permit_action(:destroy) } end
      context "as entity owner"        do let(:user) { owner };  it { is_expected.to permit_action(:destroy) } end
      context "as another member"      do let(:user) { member }; it { is_expected.not_to permit_action(:destroy) } end
    end

    context "when the document is finalized" do
      let(:document) { create(:document, :finalized, entity: entity, created_by: author) }
      let(:cc_recipient) { create(:cc_recipient, document: document) }

      context "as entity owner" do let(:user) { owner }; it { is_expected.not_to permit_action(:destroy) } end
    end
  end
end
