# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entities::MemberRowComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let(:member_user) { create(:user, email: "member@example.com") }

  let!(:owner_membership) { create(:entity_user, :owner, entity: entity, user: owner) }
  let!(:member_membership) { create(:entity_user, entity: entity, user: member_user, role: "member") }

  subject { render_inline(described_class.new(entity_user: member_membership, current_user: current_user, entity: entity)) }

  context "when the current user can manage members" do
    let(:current_user) { owner }

    it "displays the member's email" do
      expect(subject).to have_text("member@example.com")
    end

    it "displays the member's role badge" do
      expect(subject).to have_css("span", text: "Member")
    end

    it "displays a remove action" do
      expect(subject).to have_css("a[data-turbo-method='delete']", text: /Remove/)
    end
  end

  context "when the current user cannot manage members" do
    let(:current_user) { member_user }

    it "does not display a remove action" do
      expect(subject).not_to have_css("a[data-turbo-method='delete']")
    end
  end

  context "when the membership is pending" do
    let(:current_user) { owner }
    let!(:member_membership) { create(:entity_user, :pending, entity: entity, user: nil, invited_email: "invited@example.com", role: "member") }

    it "displays the invited email" do
      expect(subject).to have_text("invited@example.com")
    end

    it "displays a pending badge" do
      expect(subject).to have_css("span", text: "Pending")
    end
  end
end
