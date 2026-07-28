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

  describe "branding" do
    context "when the entity has both a logo and an acronym" do
      let(:entity) { create(:entity, :with_logo, name: "Acme Corp") }

      it "shows the logo and acronym instead of the full name" do
        expect(rendered).to have_css("img")
        expect(rendered).to have_text(entity.acronym)
        expect(rendered).not_to have_text(entity.name)
        expect(rendered).to have_text(entity.code)
      end
    end

    context "when the entity has an acronym but no logo" do
      let(:entity) { create(:entity, name: "Acme Corp", acronym: "ACR") }

      it "falls back to the full name" do
        expect(rendered).to have_text(entity.name)
        expect(rendered).not_to have_css("img")
      end
    end
  end

  describe "Documents section" do
    it "links to Overview, To Validate, My Inbox, My Outbox, ToDo, Waiting and Info, in that order" do
      expect(rendered).to have_link("Overview", href: entity_documents_path(entity))
      expect(rendered).to have_link("To Validate", href: to_validate_entity_documents_path(entity))
      expect(rendered).to have_link("My Inbox", href: received_entity_documents_path(entity))
      expect(rendered).to have_link("My Outbox", href: mine_entity_documents_path(entity))
      expect(rendered).to have_link("ToDo", href: todo_entity_documents_path(entity))
      expect(rendered).to have_link("Waiting", href: waiting_entity_documents_path(entity))
      expect(rendered).to have_link("Info", href: info_entity_documents_path(entity))

      links = rendered.css("nav a").map { |a| a.text.squish }
      overview_index = links.index { |text| text.start_with?("Overview") }
      to_validate_index = links.index { |text| text.start_with?("To Validate") }
      inbox_index = links.index { |text| text.start_with?("My Inbox") }
      outbox_index = links.index { |text| text.start_with?("My Outbox") }
      todo_index = links.index { |text| text.start_with?("ToDo") }
      waiting_index = links.index { |text| text.start_with?("Waiting") }
      info_index = links.index { |text| text.start_with?("Info") }

      expect(overview_index).to be < to_validate_index
      expect(to_validate_index).to be < inbox_index
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

    context "when on the to validate page" do
      let(:current_path) { to_validate_entity_documents_path(entity) }

      it "highlights only To Validate" do
        expect(rendered).to have_css("a.bg-primary-100", text: "To Validate")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Overview")
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
      expect(link_text(entity_documents_path(entity))).to eq("Overview 0")
      expect(link_text(to_validate_entity_documents_path(entity))).to eq("To Validate 0")
      expect(link_text(received_entity_documents_path(entity))).to eq("My Inbox 0")
      expect(link_text(mine_entity_documents_path(entity))).to eq("My Outbox 0")
      expect(link_text(todo_entity_documents_path(entity))).to eq("ToDo 0")
      expect(link_text(waiting_entity_documents_path(entity))).to eq("Waiting 0")
      expect(link_text(info_entity_documents_path(entity))).to eq("Info 0")
    end

    it "counts documents where the user is the actor of the current pending step as To Validate" do
      document = create(:document, :with_workflow, :in_progress, entity: entity)
      document.workflow_steps.find_by(role: "RED").update!(status: "approved")
      document.workflow_steps.find_by(role: "VISA").update!(actor: user)

      expect(link_text(to_validate_entity_documents_path(entity))).to eq("To Validate 1")
    end

    it "does not count a document as To Validate when the user's step is not yet current" do
      document = create(:document, :with_workflow, :in_progress, entity: entity)
      document.workflow_steps.find_by(role: "SIGN").update!(actor: user)

      expect(link_text(to_validate_entity_documents_path(entity))).to eq("To Validate 0")
    end

    it "counts documents authored by the user as My Outbox" do
      create(:document, entity: entity, created_by: user)

      expect(link_text(mine_entity_documents_path(entity))).to eq("My Outbox 1")
    end

    it "excludes the user's finalized documents from the My Outbox count" do
      create(:document, :finalized, entity: entity, created_by: user)

      expect(link_text(mine_entity_documents_path(entity))).to eq("My Outbox 0")
    end

    it "only counts finalized documents in the Unclassified badge" do
      create(:document, :finalized, entity: entity)
      create(:document, entity: entity)

      unclassified_href = entity_documents_path(entity, classification_node_id: "unclassified")
      expect(link_text(unclassified_href)).to eq("Unclassified 1")
    end

    it "only counts finalized documents as Overview" do
      create(:document, :finalized, entity: entity, created_by: user)
      create(:document, entity: entity, created_by: user)

      expect(link_text(entity_documents_path(entity))).to eq("Overview 1")
    end

    it "counts documents addressed to the user as My Inbox" do
      create(:document, entity: entity, addressee: user)

      expect(link_text(received_entity_documents_path(entity))).to eq("My Inbox 1")
    end

    it "counts documents addressed to the user expecting a response as ToDo" do
      create(:document, :finalized, :expecting_response, entity: entity, addressee: user)

      expect(link_text(todo_entity_documents_path(entity))).to eq("ToDo 1")
    end

    it "excludes a matching ToDo document that is not yet finalized" do
      create(:document, :expecting_response, entity: entity, addressee: user)

      expect(link_text(todo_entity_documents_path(entity))).to eq("ToDo 0")
    end

    it "counts documents authored by the user expecting a response as Waiting" do
      create(:document, :finalized, :expecting_response, entity: entity, created_by: user)

      expect(link_text(waiting_entity_documents_path(entity))).to eq("Waiting 1")
    end

    it "excludes a matching Waiting document that is not yet finalized" do
      create(:document, :expecting_response, entity: entity, created_by: user)

      expect(link_text(waiting_entity_documents_path(entity))).to eq("Waiting 0")
    end

    it "counts documents addressed to the user not expecting a response as Info" do
      create(:document, :finalized, entity: entity, addressee: user)

      expect(link_text(info_entity_documents_path(entity))).to eq("Info 1")
    end

    it "excludes a matching Info document that is not yet finalized" do
      create(:document, entity: entity, addressee: user)

      expect(link_text(info_entity_documents_path(entity))).to eq("Info 0")
    end
  end

  describe "Incoming Mail section" do
    it "links to the Incoming Inbox and Pending Triage views" do
      expect(rendered).to have_link("Incoming Inbox", href: inbox_entity_incoming_mails_path(entity))
      expect(rendered).to have_link("Pending Triage", href: pending_triage_entity_incoming_mails_path(entity))
    end

    context "when on the incoming inbox page" do
      let(:current_path) { inbox_entity_incoming_mails_path(entity) }

      it "highlights only Incoming Inbox" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Incoming Inbox")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Pending Triage")
      end
    end

    context "when on the pending triage page" do
      let(:current_path) { pending_triage_entity_incoming_mails_path(entity) }

      it "highlights only Pending Triage" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Pending Triage")
        expect(rendered).not_to have_css("a.bg-primary-100", text: "Incoming Inbox")
      end
    end

    describe "count badges" do
      let!(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }

      def link_text(href)
        rendered.css("a[href='#{href}']").first.text.squish
      end

      it "shows zero counts when there is no incoming mail" do
        expect(link_text(inbox_entity_incoming_mails_path(entity))).to eq("Incoming Inbox 0")
        expect(link_text(pending_triage_entity_incoming_mails_path(entity))).to eq("Pending Triage 0")
      end

      it "counts incoming mail addressed to the user as Incoming Inbox" do
        create(:document, :incoming, entity: entity, lead_user: user, addressee: user)

        expect(link_text(inbox_entity_incoming_mails_path(entity))).to eq("Incoming Inbox 1")
      end

      it "counts incoming mail awaiting the user's triage as Pending Triage" do
        create(:document, :incoming, entity: entity, lead_user: user, addressee: user)

        expect(link_text(pending_triage_entity_incoming_mails_path(entity))).to eq("Pending Triage 1")
      end

      it "does not count routed mail as Pending Triage" do
        create(:document, :incoming, entity: entity, lead_user: user, addressee: user, routed_at: Time.current)

        expect(link_text(pending_triage_entity_incoming_mails_path(entity))).to eq("Pending Triage 0")
      end

      it "does not count outgoing documents in either badge" do
        create(:document, entity: entity, addressee: user)

        expect(link_text(inbox_entity_incoming_mails_path(entity))).to eq("Incoming Inbox 0")
        expect(link_text(pending_triage_entity_incoming_mails_path(entity))).to eq("Pending Triage 0")
      end
    end
  end

  describe "Classification section" do
    it "links to manage classification nodes" do
      expect(rendered).to have_link("Manage", href: entity_classification_nodes_path(entity))
    end

    it "links to the unclassified documents view" do
      expect(rendered).to have_link("Unclassified", href: entity_documents_path(entity, classification_node_id: "unclassified"))
    end

    context "when on the unclassified documents page" do
      let(:current_path) { entity_documents_path(entity, classification_node_id: "unclassified") }

      it "highlights the Unclassified link" do
        expect(rendered).to have_css("a.bg-primary-100", text: "Unclassified")
      end
    end

    context "as owner with classification nodes" do
      let(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }
      let(:root) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }
      let!(:child) { create(:classification_node, entity: entity, parent: root, code: "1.1", name: "Drafts") }

      subject(:rendered) do
        with_request_url(current_path) do
          render_inline(described_class.new(current_entity: entity, current_user: user, current_entity_user: entity_user))
        end
      end

      it "shows the root node and its child" do
        root
        child

        expect(rendered).to have_link("Contracts", href: entity_documents_path(entity, classification_node_id: root.id))
        expect(rendered).to have_link("Drafts", href: entity_documents_path(entity, classification_node_id: child.id))
      end

      it "shows the count of accessible documents classified under each node" do
        department = create(:department, entity: entity)
        create(:document, :finalized, entity: entity, department: department, classification_node: root)
        create(:document, :finalized, entity: entity, department: department, classification_node: root)

        expect(rendered.css("a[href='#{entity_documents_path(entity, classification_node_id: root.id)}']").first.text.squish).to eq("1 Contracts 2")
      end

      context "when on a given node's filtered page" do
        let(:current_path) { entity_documents_path(entity, classification_node_id: root.id) }

        it "highlights only that node" do
          expect(rendered).to have_css("a.bg-primary-100", text: "Contracts")
          expect(rendered).not_to have_css("a.bg-primary-100", text: "Drafts")
        end
      end
    end

    context "as a regular member" do
      let(:entity_user) { create(:entity_user, entity: entity, user: user, role: "member") }

      before do
        create(:classification_node, entity: entity, code: "1", name: "Contracts")
      end

      subject(:rendered) do
        with_request_url(current_path) do
          render_inline(described_class.new(current_entity: entity, current_user: user, current_entity_user: entity_user))
        end
      end

      it "still shows the entity-wide classification nodes since filing is free for any staff member" do
        expect(rendered).to have_text("Contracts")
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

      it "does not show a logo image when the department has none" do
        expect(rendered).not_to have_css("img")
      end
    end

    context "when the current user's department has a logo" do
      let(:finance) { create(:department, :with_logo, entity: entity, name: "Finance") }
      let(:entity_user) { create(:entity_user, entity: entity, user: user, role: "member") }

      before { create(:entity_user_department, :primary, entity_user: entity_user, department: finance) }

      subject(:rendered) do
        with_request_url(current_path) do
          render_inline(described_class.new(current_entity: entity, current_user: user, current_entity_user: entity_user))
        end
      end

      it "shows the logo before the department name" do
        expect(rendered).to have_css("img")
        expect(rendered).to have_text("Finance")
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
