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
    it "links to Overview, My Inbox, My Outbox, ToDo, Waiting and Info, in that order" do
      expect(rendered).to have_link("Overview", href: entity_documents_path(entity))
      expect(rendered).to have_link("My Inbox", href: received_entity_documents_path(entity))
      expect(rendered).to have_link("My Outbox", href: mine_entity_documents_path(entity))
      expect(rendered).to have_link("ToDo", href: todo_entity_documents_path(entity))
      expect(rendered).to have_link("Waiting", href: waiting_entity_documents_path(entity))
      expect(rendered).to have_link("Info", href: info_entity_documents_path(entity))

      links = rendered.css("nav a").map { |a| a.text.squish }
      overview_index = links.index("Overview")
      inbox_index = links.index { |text| text.start_with?("My Inbox") }
      outbox_index = links.index { |text| text.start_with?("My Outbox") }
      todo_index = links.index { |text| text.start_with?("ToDo") }
      waiting_index = links.index { |text| text.start_with?("Waiting") }
      info_index = links.index { |text| text.start_with?("Info") }

      expect(overview_index).to be < inbox_index
      expect(inbox_index).to be < outbox_index
      expect(outbox_index).to be < todo_index
      expect(todo_index).to be < waiting_index
      expect(waiting_index).to be < info_index
    end

    context "when on the documents overview page" do
      let(:current_path) { entity_documents_path(entity) }

      it "highlights only Overview" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Overview")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "My Inbox")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "My Outbox")
      end
    end

    context "when on the my outbox page" do
      let(:current_path) { mine_entity_documents_path(entity) }

      it "highlights only My Outbox" do
        expect(rendered).to have_css("a.bg-primary-100", text: "My Outbox")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
      end
    end

    context "when on the my inbox page" do
      let(:current_path) { received_entity_documents_path(entity) }

      it "highlights only My Inbox" do
        expect(rendered).to have_css("a.bg-primary-100", text: "My Inbox")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
      end
    end

    context "when on the todo page" do
      let(:current_path) { todo_entity_documents_path(entity) }

      it "highlights only ToDo" do
        expect(rendered).to have_css("a.bg-primary-100", text: "ToDo")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "My Inbox")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "My Outbox")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Waiting")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Info")
      end
    end

    context "when on the waiting page" do
      let(:current_path) { waiting_entity_documents_path(entity) }

      it "highlights only Waiting" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Waiting")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "ToDo")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Info")
      end
    end

    context "when on the info page" do
      let(:current_path) { info_entity_documents_path(entity) }

      it "highlights only Info" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Info")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "ToDo")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Waiting")
      end
    end
  end

  describe "document count badges" do
    let!(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }

    def link_text(href)
      rendered.css("a[href='#{href}']").first.text.squish
    end

    it "shows zero counts when the boxes are empty" do
      expect(link_text(received_entity_documents_path(entity))).to eq("My Inbox 0")
      expect(link_text(mine_entity_documents_path(entity))).to eq("My Outbox 0")
      expect(link_text(todo_entity_documents_path(entity))).to eq("ToDo 0")
      expect(link_text(waiting_entity_documents_path(entity))).to eq("Waiting 0")
      expect(link_text(info_entity_documents_path(entity))).to eq("Info 0")
    end

    it "counts documents authored by the user as My Outbox" do
      create(:document, entity: entity, created_by: user)

      expect(link_text(mine_entity_documents_path(entity))).to eq("My Outbox 1")
    end

    it "counts documents addressed to the user as My Inbox" do
      create(:document, entity: entity, addressee: user)

      expect(link_text(received_entity_documents_path(entity))).to eq("My Inbox 1")
    end

    it "counts documents addressed to the user expecting a response as ToDo" do
      create(:document, :expecting_response, entity: entity, addressee: user)

      expect(link_text(todo_entity_documents_path(entity))).to eq("ToDo 1")
    end

    it "counts documents authored by the user expecting a response as Waiting" do
      create(:document, :expecting_response, entity: entity, created_by: user)

      expect(link_text(waiting_entity_documents_path(entity))).to eq("Waiting 1")
    end

    it "counts documents addressed to the user not expecting a response as Info" do
      create(:document, entity: entity, addressee: user)

      expect(link_text(info_entity_documents_path(entity))).to eq("Info 1")
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
