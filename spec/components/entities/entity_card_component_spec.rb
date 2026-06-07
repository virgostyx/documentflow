# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entities::EntityCardComponent, type: :component do
  let(:user) { create(:user) }
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:role) { "owner" }

  let!(:membership) { create(:entity_user, entity: entity, user: user, role: role) }

  subject { render_inline(described_class.new(entity: entity, current_user: user)) }

  it "displays the entity name" do
    expect(subject).to have_text("Acme Corp")
  end

  it "displays the entity code" do
    expect(subject).to have_text(entity.code)
  end

  it "links to the entity page" do
    expect(subject).to have_link(href: Rails.application.routes.url_helpers.entity_path(entity))
  end

  it "displays the current user's role badge" do
    expect(subject).to have_css("span", text: "Owner")
  end

  context "when the current user is a guest" do
    let(:role) { "guest" }

    it "displays the guest role badge" do
      expect(subject).to have_css("span", text: "Guest")
    end
  end
end
