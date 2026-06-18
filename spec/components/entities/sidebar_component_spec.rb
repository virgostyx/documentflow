# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entities::SidebarComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user, email: "alice@example.com") }
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:current_path) { entity_documents_path(entity) }

  subject(:rendered) do
    with_request_url(current_path) do
      render_inline(described_class.new(current_entity: entity, current_user: user))
    end
  end

  it "links to the dashboard for branding" do
    expect(rendered).to have_link(href: dashboard_path)
    expect(rendered).to have_text("DocumentFlow")
  end

  it "shows the current entity name and code" do
    expect(rendered).to have_text(entity.name)
    expect(rendered).to have_text(entity.code)
  end

  it "links to switch entities" do
    expect(rendered).to have_link("Switch entity", href: entities_path)
  end

  describe "Documents section" do
    it "links to Overview, My documents and Received documents" do
      expect(rendered).to have_link("Overview", href: entity_documents_path(entity))
      expect(rendered).to have_link("My documents", href: mine_entity_documents_path(entity))
      expect(rendered).to have_link("Received documents", href: received_entity_documents_path(entity))
    end

    context "when on the documents overview page" do
      let(:current_path) { entity_documents_path(entity) }

      it "highlights only Overview" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Overview")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "My documents")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Received documents")
      end
    end

    context "when on the my documents page" do
      let(:current_path) { mine_entity_documents_path(entity) }

      it "highlights only My documents" do
        expect(rendered).to have_css("a.bg-primary-100", text: "My documents")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
      end
    end

    context "when on the received documents page" do
      let(:current_path) { received_entity_documents_path(entity) }

      it "highlights only Received documents" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Received documents")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
      end
    end
  end

  describe "Contacts section" do
    it "links to the contacts overview" do
      expect(rendered).to have_link("Overview", href: entity_contacts_path(entity))
    end

    context "when on the contacts overview page" do
      let(:current_path) { entity_contacts_path(entity) }

      it "highlights the contacts Overview link" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Overview")
      end
    end
  end

  describe "Settings section" do
    it "links to settings" do
      expect(rendered).to have_link("Settings", href: entity_settings_path(entity))
    end

    context "when on the settings page" do
      let(:current_path) { entity_settings_path(entity) }

      it "highlights the Settings link" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Settings")
      end
    end
  end

  describe "user section" do
    it "shows the user's email and initials" do
      expect(rendered).to have_text("alice@example.com")
      expect(rendered).to have_css("span", text: "A")
    end

    it "renders sign out as a link with turbo_method delete" do
      expect(rendered).to have_css("a[data-turbo-method='delete']", text: "Sign out")
    end
  end

  describe "department badge" do
    let(:finance) { create(:department, entity: entity, name: "Finance") }
    let(:sales) { create(:department, entity: entity, name: "Sales") }

    context "when no current_entity_user is given" do
      it "does not show any department badge" do
        expect(rendered).not_to have_text("All departments")
      end
    end

    context "when the current user is an owner or admin" do
      let(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }

      subject(:rendered) do
        with_request_url(current_path) do
          render_inline(described_class.new(current_entity: entity, current_user: user, current_entity_user: entity_user))
        end
      end

      it "shows an All departments badge" do
        expect(rendered).to have_text("All departments")
      end
    end

    context "when the current user belongs to a single department" do
      let(:entity_user) { create(:entity_user, entity: entity, user: user, role: "member") }

      before { create(:entity_user_department, :primary, entity_user: entity_user, department: finance) }

      subject(:rendered) do
        with_request_url(current_path) do
          render_inline(described_class.new(current_entity: entity, current_user: user, current_entity_user: entity_user))
        end
      end

      it "shows the department name" do
        expect(rendered).to have_text("Finance")
        expect(rendered).not_to have_text("All departments")
      end
    end

    context "when the current user belongs to multiple departments" do
      let(:entity_user) { create(:entity_user, entity: entity, user: user, role: "member") }

      before do
        create(:entity_user_department, :primary, entity_user: entity_user, department: finance)
        create(:entity_user_department, entity_user: entity_user, department: sales)
      end

      subject(:rendered) do
        with_request_url(current_path) do
          render_inline(described_class.new(current_entity: entity, current_user: user, current_entity_user: entity_user))
        end
      end

      it "shows both department names" do
        expect(rendered).to have_text("Finance")
        expect(rendered).to have_text("Sales")
      end
    end
  end
end
