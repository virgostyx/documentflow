# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Documents", type: :request do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:user) { create(:user) }
  let(:sender) { create(:contact, entity: entity) }
  let(:addressee) { create(:contact, entity: entity) }

  describe "GET /entities/:entity_id/documents" do
    context "when not signed in" do
      it "redirects to sign in" do
        get entity_documents_path(entity)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user is an active member" do
      let!(:document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Supplier contract") }

      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "lists the entity's documents" do
        get entity_documents_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document.subject)
      end

      it "never lists incoming mail, even when routed" do
        routed = create(:document, :incoming, :routed, entity: entity, department: department, subject: "Routed incoming mail")

        get entity_documents_path(entity)

        expect(response.body).not_to include(routed.subject)
      end

      it "wraps the results in a turbo frame targeted by the search form" do
        get entity_documents_path(entity)

        expect(response.body).to include('<turbo-frame id="documents_list"')
        expect(response.body).to include('data-turbo-frame="documents_list"')
      end

      it "shows a response-expected badge for documents flagged as such" do
        expecting = create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Needs a reply")

        get entity_documents_path(entity)

        expect(response.body).to include("Response expected")
        expect(response.body).to include("Needs a reply")
      end

      it "shows the response deadline for documents that have one" do
        create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Needs a reply by deadline", response_deadline: Date.new(2026, 7, 1))

        get entity_documents_path(entity)

        expect(response.body).to include("Due #{I18n.l(Date.new(2026, 7, 1))}")
      end

      it "does not show a deadline for documents without one" do
        create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Needs a reply, no deadline")

        get entity_documents_path(entity)

        expect(response.body).not_to include("Due ")
      end

      it "shows the deadline in red when today is on or after the deadline" do
        travel_to Date.new(2026, 7, 1) do
          create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Overdue reply", response_deadline: Date.new(2026, 7, 1))

          get entity_documents_path(entity)

          expect(response.body).to include("bg-danger-100")
        end
      end

      it "shows the deadline in yellow when today is the day before the deadline" do
        travel_to Date.new(2026, 7, 1) do
          create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Reply due tomorrow", response_deadline: Date.new(2026, 7, 2))

          get entity_documents_path(entity)

          expect(response.body).to include("bg-warning-100")
        end
      end

      it "shows the deadline without a color when it is further away" do
        travel_to Date.new(2026, 7, 1) do
          create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Reply due later", response_deadline: Date.new(2026, 7, 10))

          get entity_documents_path(entity)

          expect(response.body).not_to include("bg-danger-100")
          expect(response.body).not_to include("bg-warning-100")
        end
      end

      it "shows a Reply button for documents awaiting a response from the current user" do
        awaiting = create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Needs my reply")

        get entity_documents_path(entity)

        expect(response.body).to include("Reply")
        expect(response.body).to include(new_entity_document_path(entity, reply_to: awaiting.id))
      end

      it "does not show a Reply button when the current user is not the one expected to respond" do
        get entity_documents_path(entity)

        expect(response.body).not_to include("Reply")
      end

      it "filters by the search query" do
        other = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Annual report")

        get entity_documents_path(entity), params: { q: "Supplier" }

        expect(response.body).to include(document.subject)
        expect(response.body).not_to include(other.subject)
      end

      it "renders documents in a table with sortable column headers" do
        get entity_documents_path(entity)

        expect(response.body).to include("<table")
        expect(response.body).to include("sort=reference_number")
        expect(response.body).to include("sort=subject")
        expect(response.body).to include("sort=document_date")
        expect(response.body).to include("sort=status")
      end

      it "sorts documents by document date, most recent first, by default" do
        older = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Older contract", document_date: 5.days.ago.to_date)
        newer = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Newer contract", document_date: Date.current)

        get entity_documents_path(entity)

        expect(response.body.index(newer.subject)).to be < response.body.index(older.subject)
      end

      it "sorts by an explicit column and direction" do
        alpha = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Alpha contract")
        beta = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Beta contract")

        get entity_documents_path(entity), params: { sort: "subject", direction: "asc" }

        expect(response.body.index(alpha.subject)).to be < response.body.index(beta.subject)
      end

      it "filters by status" do
        get entity_documents_path(entity), params: { status: "finalized" }

        expect(response.body).to include(document.subject)
      end

      it "excludes documents that are not finalized, even when a non-finalized status is requested" do
        create(:document, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee, subject: "In progress contract")

        get entity_documents_path(entity), params: { status: "in_progress" }

        expect(response.body).not_to include("In progress contract")
      end

      it "paginates the results" do
        allow(Kaminari.config).to receive(:default_per_page).and_return(1)
        create_list(:document, 2, :finalized, entity: entity, department: department, sender: sender, addressee: addressee)

        get entity_documents_path(entity)

        expect(response.body).to include("page=2")
      end

      it "excludes a document that is not yet finalized" do
        not_finalized = create(:document, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Draft supplier contract")

        get entity_documents_path(entity)

        expect(response.body).not_to include(not_finalized.subject)
      end
    end

    context "when the user is not a member of the entity" do
      before { sign_in user }

      it "redirects to the dashboard with an access denied alert" do
        get entity_documents_path(entity)

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the user is a regular member of a single department" do
      let(:other_department) { create(:department, entity: entity) }
      let!(:own_department_document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Own department deal") }
      let!(:other_department_document) { create(:document, :finalized, entity: entity, department: other_department, sender: sender, addressee: addressee, subject: "Other department deal") }

      before do
        eu = create(:entity_user, entity: entity, user: user, role: "member")
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "only shows documents belonging to the user's department(s)" do
        get entity_documents_path(entity)

        expect(response.body).to include(own_department_document.subject)
        expect(response.body).not_to include(other_department_document.subject)
      end
    end

    context "when the user is an owner" do
      let(:other_department) { create(:department, entity: entity) }
      let!(:department_document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Department deal") }
      let!(:other_department_document) { create(:document, :finalized, entity: entity, department: other_department, sender: sender, addressee: addressee, subject: "Other department deal") }

      before do
        create(:entity_user, entity: entity, user: user, role: "owner")
        sign_in user
      end

      it "shows documents across all departments" do
        get entity_documents_path(entity)

        expect(response.body).to include(department_document.subject)
        expect(response.body).to include(other_department_document.subject)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/mine" do
    let!(:mine) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "My contract", created_by: user) }
    let!(:others_document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Colleague's contract") }
    let!(:my_finalized_document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "My finalized contract", created_by: user) }

    before do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      sign_in user
    end

    it "lists only documents created by the current user" do
      get mine_entity_documents_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(mine.subject)
      expect(response.body).not_to include(others_document.subject)
    end

    it "excludes the current user's finalized documents" do
      get mine_entity_documents_path(entity)

      expect(response.body).not_to include(my_finalized_document.subject)
    end

    it "never lists incoming mail, even when routed and created by the current user" do
      routed = create(:document, :incoming, :routed, entity: entity, department: department, created_by: user, subject: "Routed incoming mail")

      get mine_entity_documents_path(entity)

      expect(response.body).not_to include(routed.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/received" do
    let!(:entity_user) do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      eu
    end
    let!(:addressed_to_me) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: user, subject: "Addressed to me") }
    let!(:cc_to_me) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Copied to me") }
    let!(:not_received) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Not received") }
    let!(:not_finalized_addressed_to_me) { create(:document, entity: entity, department: department, sender: sender, addressee: user, subject: "Not yet finalized") }

    before do
      create(:cc_recipient, document: cc_to_me, party: user)
      sign_in user
    end

    it "lists finalized documents where the current user is the addressee or a cc recipient" do
      get received_entity_documents_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(addressed_to_me.subject)
      expect(response.body).to include(cc_to_me.subject)
      expect(response.body).not_to include(not_received.subject)
    end

    it "excludes documents that are not yet finalized" do
      get received_entity_documents_path(entity)

      expect(response.body).not_to include(not_finalized_addressed_to_me.subject)
    end

    it "never lists incoming mail, even when routed to the current user" do
      routed = create(:document, :incoming, :routed, entity: entity, department: department, addressee: user, subject: "Routed incoming mail")

      get received_entity_documents_path(entity)

      expect(response.body).not_to include(routed.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/todo" do
    let!(:entity_user) do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      eu
    end
    let!(:todo) { create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Needs my reply") }
    let!(:addressed_no_response) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: user, subject: "Addressed to me, no reply needed") }
    let!(:cc_expecting_response) { create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Copied to me, expecting a reply") }

    before do
      create(:cc_recipient, document: cc_expecting_response, party: user)
      sign_in user
    end

    it "lists only documents where the current user is the addressee and a response is expected" do
      get todo_entity_documents_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(todo.subject)
      expect(response.body).not_to include(addressed_no_response.subject)
      expect(response.body).not_to include(cc_expecting_response.subject)
    end

    it "excludes a matching document that is not yet finalized" do
      not_finalized = create(:document, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Not finalized yet")

      get todo_entity_documents_path(entity)

      expect(response.body).not_to include(not_finalized.subject)
    end

    it "excludes a document once the user has posted a finalized reply to it" do
      create(:document, :finalized, entity: entity, department: department, sender: sender,
                         created_by: user, in_reply_to: todo, subject: "My finalized reply")

      get todo_entity_documents_path(entity)

      expect(response.body).not_to include(todo.subject)
    end

    it "includes a routed incoming document where the user is the action assignee expecting a response" do
      assignee = create(:user)
      assignee_membership = create(:entity_user, entity: entity, user: assignee, status: "active")
      create(:entity_user_department, entity_user: assignee_membership, department: department)
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, department: department,
                                  addressee: assignee, subject: "Routed mail needing action")

      sign_out user
      sign_in assignee
      get todo_entity_documents_path(entity)

      expect(response.body).to include(routed.subject)
      expect(response.body).to include(%(href="#{entity_incoming_mail_path(entity, routed)}"))
      expect(response.body).not_to include(%(href="#{entity_document_path(entity, routed)}"))
    end

    it "excludes an unrouted incoming document even when the user is its lead" do
      pending_mail = create(:document, :incoming, entity: entity, department: department, lead_user: user, subject: "Awaiting triage")

      get todo_entity_documents_path(entity)

      expect(response.body).not_to include(pending_mail.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/waiting" do
    let!(:entity_user) do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      eu
    end
    let!(:waiting) { create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Waiting on a reply", created_by: user) }
    let!(:mine_no_response) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "No reply needed", created_by: user) }
    let!(:others_expecting_response) { create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Colleague is waiting") }

    before { sign_in user }

    it "lists only documents created by the current user where a response is expected" do
      get waiting_entity_documents_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(waiting.subject)
      expect(response.body).not_to include(mine_no_response.subject)
      expect(response.body).not_to include(others_expecting_response.subject)
    end

    it "excludes a matching document that is not yet finalized" do
      not_finalized = create(:document, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Not finalized yet", created_by: user)

      get waiting_entity_documents_path(entity)

      expect(response.body).not_to include(not_finalized.subject)
    end

    it "excludes a document once it has received a finalized reply" do
      create(:document, :finalized, entity: entity, department: department, sender: addressee,
                         addressee: sender, in_reply_to: waiting, subject: "A finalized reply")

      get waiting_entity_documents_path(entity)

      expect(response.body).not_to include(waiting.subject)
    end

    it "includes a routed incoming document for the lead when a response is expected, not for the registrant" do
      registrant = create(:user)
      create(:entity_user, entity: entity, user: registrant, status: "active")
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, department: department,
                                  lead_user: user, created_by: registrant, subject: "Mail awaiting a reply")

      get waiting_entity_documents_path(entity)
      expect(response.body).to include(routed.subject)

      sign_out user
      sign_in registrant
      get waiting_entity_documents_path(entity)
      expect(response.body).not_to include(routed.subject)
    end

    it "excludes a routed incoming document from the lead's waiting list when no response is expected" do
      routed = create(:document, :incoming, :routed, entity: entity, department: department, lead_user: user, subject: "Routed, no reply needed")

      get waiting_entity_documents_path(entity)

      expect(response.body).not_to include(routed.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/to_validate" do
    let!(:entity_user) do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      eu
    end
    let!(:to_validate) { create(:document, :with_workflow, :in_progress, entity: entity, department: department, subject: "Awaiting my VISA") }
    let!(:not_yet_my_turn) { create(:document, :with_workflow, :in_progress, entity: entity, department: department, subject: "Not my turn yet") }

    before do
      to_validate.workflow_steps.find_by(role: "RED").update!(status: "approved")
      to_validate.workflow_steps.find_by(role: "VISA").update!(actor: user)
      not_yet_my_turn.workflow_steps.find_by(role: "SIGN").update!(actor: user)

      sign_in user
    end

    it "lists only documents where the current user is the actor of the current pending step" do
      get to_validate_entity_documents_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(to_validate.subject)
      expect(response.body).not_to include(not_yet_my_turn.subject)
    end

    context "when the document belongs to a department the user is not a member of" do
      let(:other_department) { create(:department, entity: entity) }
      let!(:outside_department) { create(:document, :with_workflow, :in_progress, entity: entity, department: other_department, subject: "Outside my department") }

      before do
        outside_department.workflow_steps.find_by(role: "RED").update!(status: "approved")
        outside_department.workflow_steps.find_by(role: "VISA").update!(actor: user)
      end

      it "still lists it, since a step actor is authorized regardless of department" do
        get to_validate_entity_documents_path(entity)

        expect(response.body).to include(outside_department.subject)
      end
    end

    it "never lists incoming mail, even when routed to the current user" do
      routed = create(:document, :incoming, :routed, entity: entity, department: department, addressee: user, subject: "Routed incoming mail")

      get to_validate_entity_documents_path(entity)

      expect(response.body).not_to include(routed.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/info" do
    let!(:entity_user) do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      eu
    end
    let!(:cc_to_me) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Copied to me") }
    let!(:addressed_no_response) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: user, subject: "Addressed to me, no reply needed") }
    let!(:mine_no_response) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "No reply needed", created_by: user) }
    let!(:todo) { create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Needs my reply") }
    let!(:waiting) { create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Waiting on a reply", created_by: user) }

    before do
      create(:cc_recipient, document: cc_to_me, party: user)
      sign_in user
    end

    it "lists cc'd documents and documents not expecting a response, excluding ToDo and Waiting documents" do
      get info_entity_documents_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(cc_to_me.subject)
      expect(response.body).to include(addressed_no_response.subject)
      expect(response.body).to include(mine_no_response.subject)
      expect(response.body).not_to include(todo.subject)
      expect(response.body).not_to include(waiting.subject)
    end

    it "excludes a matching document that is not yet finalized" do
      not_finalized = create(:document, entity: entity, department: department, sender: sender, addressee: user, subject: "Not finalized yet")

      get info_entity_documents_path(entity)

      expect(response.body).not_to include(not_finalized.subject)
    end

    it "includes a routed incoming document for the lead when no response is expected" do
      routed = create(:document, :incoming, :routed, entity: entity, department: department, lead_user: user, subject: "Routed, no reply needed")

      get info_entity_documents_path(entity)

      expect(response.body).to include(routed.subject)
    end

    it "excludes a routed incoming document from the lead's info list when a response is expected" do
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, department: department, lead_user: user, subject: "Routed, awaiting reply")

      get info_entity_documents_path(entity)

      expect(response.body).not_to include(routed.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/search" do
    let!(:document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Supplier contract") }

    before do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      sign_in user
    end

    it "renders the filtered list" do
      get search_entity_documents_path(entity), params: { q: "Supplier" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(document.subject)
    end

    it "wraps the results in the documents_list turbo frame so Turbo can swap it in place" do
      get search_entity_documents_path(entity), params: { q: "Supplier" }

      expect(response.body).to include('<turbo-frame id="documents_list"')
    end

    it "re-applies the 'mine' scope when searching" do
      mine = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Mine supplier deal", created_by: user)
      other = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Other supplier deal")

      get search_entity_documents_path(entity), params: { q: "supplier", scope: "mine" }

      expect(response.body).to include(mine.subject)
      expect(response.body).not_to include(other.subject)
    end

    it "re-applies the 'received' scope when searching" do
      received = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: user, subject: "Received supplier deal")
      other = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Other supplier deal")

      get search_entity_documents_path(entity), params: { q: "supplier", scope: "received" }

      expect(response.body).to include(received.subject)
      expect(response.body).not_to include(other.subject)
    end

    it "re-applies the 'todo' scope when searching" do
      todo = create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Todo supplier deal")
      other = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Other supplier deal")

      get search_entity_documents_path(entity), params: { q: "supplier", scope: "todo" }

      expect(response.body).to include(todo.subject)
      expect(response.body).not_to include(other.subject)
    end

    it "keeps a routed incoming document matching the 'todo' scope when searching" do
      routed = create(:document, :incoming, :routed, :expecting_response, entity: entity, department: department, addressee: user, subject: "Routed supplier mail")

      get search_entity_documents_path(entity), params: { q: "supplier", scope: "todo" }

      expect(response.body).to include(routed.subject)
    end

    it "re-applies the 'waiting' scope when searching" do
      waiting = create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Waiting supplier deal", created_by: user)
      other = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Other supplier deal")

      get search_entity_documents_path(entity), params: { q: "supplier", scope: "waiting" }

      expect(response.body).to include(waiting.subject)
      expect(response.body).not_to include(other.subject)
    end

    it "re-applies the 'info' scope when searching" do
      info = create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Info supplier deal", created_by: user)
      todo = create(:document, :finalized, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Other supplier deal")

      get search_entity_documents_path(entity), params: { q: "supplier", scope: "info" }

      expect(response.body).to include(info.subject)
      expect(response.body).not_to include(todo.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/new" do
    context "when the user is staff" do
      before do
        create(:entity_user, :admin, entity: entity, user: user)
        sign_in user
      end

      it "renders the new document form" do
        get new_entity_document_path(entity)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when replying to a document awaiting the user's response" do
      let!(:entity_user) { create(:entity_user, :admin, entity: entity, user: user) }
      let!(:original) { create(:document, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Please confirm") }

      before { sign_in user }

      it "pre-fills the subject, sender and addressee for the reply" do
        get new_entity_document_path(entity, reply_to: original.id)

        expect(response.body).to include('value="Re: Please confirm"')
        expect(response.body).to include(%(selected="selected" value="User-#{user.id}"))
        expect(response.body).to include(%(selected="selected" value="Contact-#{sender.id}"))
      end

      it "carries the original document's id through as a hidden field" do
        get new_entity_document_path(entity, reply_to: original.id)

        expect(response.body).to include(%(value="#{original.id}" name="document[in_reply_to_id]" id="document_in_reply_to_id"))
      end
    end

    context "when replying to a routed incoming mail" do
      let!(:entity_user) { create(:entity_user, :admin, entity: entity, user: user) }
      let!(:incoming) { create(:document, :incoming, :routed, :expecting_response, entity: entity, department: department, addressee: user, subject: "Please respond to this mail") }

      before { sign_in user }

      it "pre-fills the reply addressed to the incoming mail's external sender" do
        get new_entity_document_path(entity, reply_to: incoming.id)

        expect(response.body).to include('value="Re: Please respond to this mail"')
        expect(response.body).to include(%(selected="selected" value="User-#{user.id}"))
        expect(response.body).to include(%(selected="selected" value="#{incoming.sender_type}-#{incoming.sender_id}"))
        expect(response.body).to include(%(value="#{incoming.id}" name="document[in_reply_to_id]" id="document_in_reply_to_id"))
      end
    end

    context "when replying to an incoming mail that has not been routed yet" do
      let!(:entity_user) { create(:entity_user, :admin, entity: entity, user: user) }
      let!(:incoming) { create(:document, :incoming, entity: entity, department: department, lead_user: user, subject: "Unrouted mail") }

      before { sign_in user }

      it "does not pre-fill the reply form" do
        get new_entity_document_path(entity, reply_to: incoming.id)

        expect(response.body).not_to include('value="Re: Unrouted mail"')
      end
    end

    context "when the user is a guest" do
      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        get new_entity_document_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/documents" do
    context "as entity staff" do
      before do
        create(:entity_user, :admin, entity: entity, user: user)
        sign_in user
      end

      context "with valid params" do
        let(:document_params) do
          {
            document: {
              subject: "New supplier agreement",
              document_date: Date.current,
              department_id: department.id,
              sender_token: "Contact-#{sender.id}",
              addressee_token: "Contact-#{addressee.id}"
            }
          }
        end

        it "creates the document" do
          expect {
            post entity_documents_path(entity), params: document_params
          }.to change(Document, :count).by(1)
        end

        it "redirects to the document page" do
          post entity_documents_path(entity), params: document_params

          document = entity.documents.find_by(subject: "New supplier agreement")
          expect(response).to redirect_to(entity_document_path(entity, document))
        end

        it "defaults expects_response to false when the checkbox is not submitted" do
          post entity_documents_path(entity), params: document_params

          document = entity.documents.find_by(subject: "New supplier agreement")
          expect(document.expects_response).to be false
        end

        it "persists expects_response as true when the checkbox is checked" do
          post entity_documents_path(entity), params: document_params.deep_merge(document: { expects_response: "1" })

          document = entity.documents.find_by(subject: "New supplier agreement")
          expect(document.expects_response).to be true
        end

        it "persists the response deadline when a response is expected" do
          post entity_documents_path(entity), params: document_params.deep_merge(document: { expects_response: "1", response_deadline: "2026-07-01" })

          document = entity.documents.find_by(subject: "New supplier agreement")
          expect(document.response_deadline).to eq(Date.new(2026, 7, 1))
        end

        it "ignores a response deadline submitted without expects_response checked" do
          post entity_documents_path(entity), params: document_params.deep_merge(document: { response_deadline: "2026-07-01" })

          document = entity.documents.find_by(subject: "New supplier agreement")
          expect(document.response_deadline).to be_nil
        end

        context "with an internal user as sender" do
          let(:document_params) do
            {
              document: {
                subject: "Internal memo",
                document_date: Date.current,
                department_id: department.id,
                sender_token: "User-#{user.id}",
                addressee_token: "Contact-#{addressee.id}"
              }
            }
          end

          it "creates the document with the user as sender" do
            post entity_documents_path(entity), params: document_params

            document = entity.documents.find_by(subject: "Internal memo")
            expect(document.sender).to eq(user)
          end
        end

        context "as a reply to another document" do
          let!(:original) { create(:document, :expecting_response, entity: entity, department: department, sender: sender, addressee: user, subject: "Please confirm") }
          let(:document_params) do
            {
              document: {
                subject: "Re: Please confirm",
                document_date: Date.current,
                department_id: department.id,
                sender_token: "User-#{user.id}",
                addressee_token: "Contact-#{sender.id}",
                in_reply_to_id: original.id
              }
            }
          end

          it "links the new document to the one it replies to" do
            post entity_documents_path(entity), params: document_params

            reply = entity.documents.find_by(subject: "Re: Please confirm")
            expect(reply.in_reply_to).to eq(original)
            expect(original.reload.replies).to contain_exactly(reply)
          end

          context "when in_reply_to_id points to a document in another entity" do
            let!(:other_entity_document) { create(:document) }
            let(:document_params) do
              {
                document: {
                  subject: "Sneaky reply",
                  document_date: Date.current,
                  department_id: department.id,
                  sender_token: "User-#{user.id}",
                  addressee_token: "Contact-#{sender.id}",
                  in_reply_to_id: other_entity_document.id
                }
              }
            end

            it "does not create the document" do
              expect {
                post entity_documents_path(entity), params: document_params
              }.not_to change(Document, :count)
            end
          end
        end
      end

      context "with invalid params" do
        let(:document_params) do
          { document: { subject: "", document_date: nil, department_id: department.id, sender_token: "Contact-#{sender.id}", addressee_token: "Contact-#{addressee.id}" } }
        end

        it "does not create the document" do
          expect {
            post entity_documents_path(entity), params: document_params
          }.not_to change(Document, :count)
        end

        it "renders the new form again" do
          post entity_documents_path(entity), params: document_params

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "when the department belongs to a department the user isn't a member of" do
        let(:other_department) { create(:department, entity: entity) }
        let(:document_params) do
          {
            document: {
              subject: "Should fail",
              document_date: Date.current,
              department_id: other_department.id,
              sender_token: "Contact-#{sender.id}",
              addressee_token: "Contact-#{addressee.id}"
            }
          }
        end

        before do
          # the admin is replaced with a plain member with no department for this scenario
          EntityUser.find_by(entity: entity, user: user).update!(role: "member")
        end

        it "does not create the document" do
          expect {
            post entity_documents_path(entity), params: document_params
          }.not_to change(Document, :count)
        end
      end
    end

    context "when the user is a guest" do
      let(:document_params) do
        { document: { subject: "Sneaky", document_date: Date.current, department_id: department.id, sender_token: "Contact-#{sender.id}", addressee_token: "Contact-#{addressee.id}" } }
      end

      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "does not create the document" do
        expect {
          post entity_documents_path(entity), params: document_params
        }.not_to change(Document, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:id" do
    let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee) }

    context "when the user is an active member of the document's department" do
      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "shows the document" do
        get entity_document_path(entity, document)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document.display_number)
        expect(response.body).to include(document.sender.full_name)
      end

      it "shows whether the document expects a response" do
        get entity_document_path(entity, document)

        expect(response.body).to include("Expects a response")
        expect(response.body).to include("No")
      end

      it "does not show a document chain section for a standalone document" do
        get entity_document_path(entity, document)

        expect(response.body).not_to include("Document chain")
      end

      it "does not show an activity history section when there are no audit logs" do
        get entity_document_path(entity, document)

        expect(response.body).not_to include("Activity history")
      end

      context "when the document has audit logs" do
        before { create(:audit_log, auditable: document, user: user, action: "launch") }

        it "shows the activity history section" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Activity history")
          expect(response.body).to include("launched the validation circuit")
        end
      end

      context "when the document is part of a reply chain" do
        let!(:reply) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, in_reply_to: document, subject: "Re: original") }

        it "shows the document chain on the original document" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Document chain")
          expect(response.body).to include(reply.display_number)
        end

        it "shows the document chain on the reply" do
          get entity_document_path(entity, reply)

          expect(response.body).to include("Document chain")
          expect(response.body).to include(document.display_number)
        end
      end

      context "when the document expects a response" do
        let!(:document) { create(:document, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee) }

        it "shows Yes" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Expects a response")
          expect(response.body).to include("Yes")
        end
      end

      context "when the document has a response deadline" do
        let!(:document) { create(:document, :expecting_response, entity: entity, department: department, sender: sender, addressee: addressee, response_deadline: Date.new(2026, 7, 1)) }

        it "shows the response deadline" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Response deadline")
          expect(response.body).to include(I18n.l(Date.new(2026, 7, 1)))
        end

        it "shows the deadline in red when today is on or after the deadline" do
          travel_to Date.new(2026, 7, 1) do
            get entity_document_path(entity, document)

            expect(response.body).to include("bg-danger-100")
          end
        end

        it "shows the deadline in yellow when today is the day before the deadline" do
          travel_to Date.new(2026, 6, 30) do
            get entity_document_path(entity, document)

            expect(response.body).to include("bg-warning-100")
          end
        end

        it "shows the deadline without a color when it is further away" do
          travel_to Date.new(2026, 6, 1) do
            get entity_document_path(entity, document)

            expect(response.body).not_to include("bg-danger-100")
            expect(response.body).not_to include("bg-warning-100")
          end
        end
      end

      it "does not show a response deadline when none is set" do
        get entity_document_path(entity, document)

        expect(response.body).not_to include("Response deadline")
      end

      context "when the document has a validation circuit" do
        let!(:document) { create(:document, :with_workflow, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee) }

        it "displays the workflow steps" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Validation circuit")
          expect(response.body).to include("RED")
          expect(response.body).to include("VISA")
        end
      end

      context "as the current step's actor" do
        let!(:document) { create(:document, :with_workflow, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

        before { document.workflow_steps.find_by(role: "RED").update!(actor: user) }

        it "displays the approve action button" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Approve")
        end

        it "requires confirmation before approving" do
          get entity_document_path(entity, document)

          expect(response.body).to include("data-turbo-confirm=\"Approve this step?\"")
        end
      end

      context "when the current step is EXP and there is an external recipient" do
        let!(:document) { create(:document, :with_workflow, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

        before do
          document.workflow_steps.where(role: %w[RED VISA SIGN]).find_each { |s| s.update!(status: "approved") }
          document.sign!
          document.workflow_steps.find_by(role: "EXP").update!(actor: user)
          sign_in user
        end

        it "links to the EXP dispatch confirmation instead of approving directly" do
          get entity_document_path(entity, document)

          exp_step = document.workflow_steps.find_by(role: "EXP")
          expect(response.body).to include(confirm_exp_entity_document_workflow_step_path(entity, document, exp_step))
        end
      end

      context "when the current step is EXP and every recipient is internal" do
        let(:internal_addressee) do
          internal_user = create(:user)
          create(:entity_user, entity: entity, user: internal_user, status: "active")
          internal_user
        end
        let!(:document) { create(:document, :with_workflow, :in_progress, entity: entity, department: department, sender: sender, addressee: internal_addressee, created_by: user) }

        before do
          document.workflow_steps.where(role: %w[RED VISA SIGN]).find_each { |s| s.update!(status: "approved") }
          document.sign!
          document.workflow_steps.find_by(role: "EXP").update!(actor: user)
          sign_in user
        end

        it "still links to the EXP dispatch confirmation, since the message field applies to internal recipients too" do
          get entity_document_path(entity, document)

          exp_step = document.workflow_steps.find_by(role: "EXP")
          expect(response.body).to include(confirm_exp_entity_document_workflow_step_path(entity, document, exp_step))
        end
      end
    end

    context "when the user is a member of a different department" do
      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: create(:department, entity: entity))
        sign_in user
      end

      it "redirects with an authorization error" do
        get entity_document_path(entity, document)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "public sharing" do
      context "when the document is finalized" do
        let!(:document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee) }
        let!(:shared_link) { create(:shared_link, document: document) }

        context "as entity staff" do
          before do
            create(:entity_user, :admin, entity: entity, user: user)
            sign_in user
          end

          it "displays the generate share link action and existing links" do
            get entity_document_path(entity, document)

            expect(response.body).to include("Generate share link")
            expect(response.body).to include(shared_document_url(token: shared_link.token))
            expect(response.body).to include("Revoke")
          end

          it "wraps the sharing actions in a turbo frame so they can be updated in place" do
            get entity_document_path(entity, document)

            expect(response.body).to match(%r{<turbo-frame id="shared_links".*Generate share link.*</turbo-frame>}m)
            expect(response.body).to match(%r{<turbo-frame id="shared_links".*Revoke.*</turbo-frame>}m)
          end
        end

        context "as a guest" do
          before do
            create(:entity_user, :guest, entity: entity, user: user)
            sign_in user
          end

          it "does not display sharing actions" do
            get entity_document_path(entity, document)

            expect(response.body).not_to include("Generate share link")
            expect(response.body).not_to include("Revoke")
          end
        end
      end

      context "when the document is not finalized" do
        let!(:document) { create(:document, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee) }

        before do
          create(:entity_user, :admin, entity: entity, user: user)
          sign_in user
        end

        it "does not display the generate share link action" do
          get entity_document_path(entity, document)

          expect(response.body).not_to include("Generate share link")
        end
      end
    end

    context "when the user is not a member" do
      before { sign_in user }

      it "redirects to the dashboard with an access denied alert" do
        get entity_document_path(entity, document)

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:id/edit" do
    let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

    context "as the document's author" do
      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "renders the edit form" do
        get edit_entity_document_path(entity, document)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as another member" do
      let(:other) { create(:user) }

      before do
        eu = create(:entity_user, entity: entity, user: other)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in other
      end

      it "redirects with an authorization error" do
        get edit_entity_document_path(entity, document)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /entities/:entity_id/documents/:id" do
    let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user, subject: "Old subject") }

    context "as the document's author" do
      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "updates the document" do
        patch entity_document_path(entity, document), params: { document: { subject: "New subject" } }

        expect(document.reload.subject).to eq("New subject")
        expect(response).to redirect_to(entity_document_path(entity, document))
      end

      it "updates expects_response to true when checked" do
        patch entity_document_path(entity, document), params: { document: { expects_response: "1" } }

        expect(document.reload.expects_response).to be true
      end

      it "updates expects_response back to false when unchecked" do
        document.update!(expects_response: true)

        patch entity_document_path(entity, document), params: { document: { expects_response: "0" } }

        expect(document.reload.expects_response).to be false
      end

      it "sets the response deadline when a response is expected" do
        patch entity_document_path(entity, document), params: { document: { expects_response: "1", response_deadline: "2026-07-01" } }

        expect(document.reload.response_deadline).to eq(Date.new(2026, 7, 1))
      end

      it "clears the response deadline when expects_response is unchecked" do
        document.update!(expects_response: true, response_deadline: Date.new(2026, 7, 1))

        patch entity_document_path(entity, document), params: { document: { expects_response: "0" } }

        expect(document.reload.response_deadline).to be_nil
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:id" do
    let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

    context "as entity owner" do
      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "destroys the document" do
        expect {
          delete entity_document_path(entity, document), params: { reason: "No longer needed" }
        }.to change(entity.documents, :count).by(-1)

        expect(response).to redirect_to(entity_documents_path(entity))
      end

      it "logs the deletion reason to the audit trail" do
        delete entity_document_path(entity, document), params: { reason: "Duplicate entry" }

        audit_log = AuditLog.find_by(action: "destroy_document")
        expect(audit_log.change_data["reason"]).to eq("Duplicate entry")
      end
    end

    context "as a regular member" do
      let(:author) { document.created_by }

      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "does not destroy the document" do
        expect {
          delete entity_document_path(entity, document)
        }.not_to change(Document, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:id/confirm_destroy" do
    let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

    context "as entity owner" do
      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "renders the confirmation modal with a required reason field" do
        get confirm_destroy_entity_document_path(entity, document)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="reason"')
        expect(response.body).to include("required")
      end
    end

    context "as a regular member" do
      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "redirects with an authorization error" do
        get confirm_destroy_entity_document_path(entity, document)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:id/launch" do
    context "as the document's author" do
      let!(:document) { create(:document, :with_workflow, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "launches the document" do
        post launch_entity_document_path(entity, document)

        expect(document.reload).to be_in_progress
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "when the document has no validation circuit" do
      let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "does not launch the document" do
        post launch_entity_document_path(entity, document)

        expect(document.reload).to be_draft
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "as another member" do
      let!(:document) { create(:document, :with_workflow, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }
      let(:other) { create(:user) }

      before do
        eu = create(:entity_user, entity: entity, user: other)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in other
      end

      it "redirects with an authorization error" do
        post launch_entity_document_path(entity, document)

        expect(document.reload).to be_draft
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:id/cancel" do
    context "as the document's author" do
      let!(:document) { create(:document, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

      before do
        eu = create(:entity_user, entity: entity, user: user)
        create(:entity_user_department, entity_user: eu, department: department)
        sign_in user
      end

      it "cancels the document" do
        post cancel_entity_document_path(entity, document), params: { reason: "Client withdrew the request" }

        expect(document.reload).to be_cancelled
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end

      it "logs the cancellation reason to the audit trail" do
        post cancel_entity_document_path(entity, document), params: { reason: "Client withdrew the request" }

        audit_log = AuditLog.find_by(action: "cancel_document")
        expect(audit_log.change_data["reason"]).to eq("Client withdrew the request")
      end
    end

    context "when the document is finalized" do
      let!(:document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

      before do
        create(:entity_user, :owner, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        post cancel_entity_document_path(entity, document)

        expect(document.reload).to be_finalized
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:id/confirm_cancel" do
    let!(:document) { create(:document, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee, created_by: user) }

    before do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      sign_in user
    end

    it "renders the confirmation modal with a required reason field" do
      get confirm_cancel_entity_document_path(entity, document)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="reason"')
      expect(response.body).to include("required")
    end
  end

  describe "PATCH /entities/:entity_id/documents/:id/classify" do
    let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee) }
    let(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }

    before do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      sign_in user
    end

    it "classifies the document under the given node" do
      patch classify_entity_document_path(entity, document), params: { classification_node_id: node.id }

      expect(document.reload.classification_node).to eq(node)
      expect(response).to redirect_to(entity_document_path(entity, document))
      expect(flash[:notice]).to be_present
    end

    it "removes the document's classification when classification_node_id is blank" do
      document.update!(classification_node: node)

      patch classify_entity_document_path(entity, document), params: { classification_node_id: "" }

      expect(document.reload.classification_node).to be_nil
      expect(flash[:notice]).to be_present
    end

    it "classifies the document under a node regardless of the document's department" do
      other_department = create(:department, entity: entity)
      document_in_other_department = create(:document, entity: entity, department: other_department, sender: sender, addressee: addressee)
      create(:entity_user_department, entity_user: EntityUser.find_by(entity: entity, user: user), department: other_department)

      patch classify_entity_document_path(entity, document_in_other_department), params: { classification_node_id: node.id }

      expect(document_in_other_department.reload.classification_node).to eq(node)
      expect(flash[:notice]).to be_present
    end

    it "rejects a classification_node_id from a different entity" do
      other_entity = create(:entity)
      foreign_node = create(:classification_node, entity: other_entity, code: "1", name: "Other entity root")

      patch classify_entity_document_path(entity, document), params: { classification_node_id: foreign_node.id }

      expect(document.reload.classification_node).to be_nil
      expect(flash[:alert]).to be_present
    end

    context "as an outsider who cannot see the document" do
      let(:outsider) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: outsider, role: "member")
        sign_in outsider
      end

      it "redirects with an authorization error" do
        patch classify_entity_document_path(entity, document), params: { classification_node_id: node.id }

        expect(document.reload.classification_node).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "classification_node_id filtering" do
    let!(:node) { create(:classification_node, entity: entity, code: "1", name: "Contracts") }
    let!(:classified_document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Classified doc", classification_node: node) }
    let!(:unclassified_document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Unclassified doc") }

    before do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      sign_in user
    end

    it "filters the index to a given classification node" do
      get entity_documents_path(entity, classification_node_id: node.id)

      expect(response.body).to include("Classified doc")
      expect(response.body).not_to include("Unclassified doc")
    end

    it "filters the index to unclassified documents" do
      get entity_documents_path(entity, classification_node_id: "unclassified")

      expect(response.body).to include("Unclassified doc")
      expect(response.body).not_to include("Classified doc")
    end

    it "carries the classification_node_id through to the search and status filter forms so it survives a search" do
      get entity_documents_path(entity, classification_node_id: node.id)

      expect(response.body).to include(%(name="classification_node_id" value="#{node.id}"))
    end

    it "excludes a classified document that is not yet finalized" do
      draft_classified = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Draft classified doc", classification_node: node, created_by: user)

      get entity_documents_path(entity, classification_node_id: node.id)

      expect(response.body).not_to include("Draft classified doc")
    end
  end

  describe "right-click classify menu on the documents table" do
    let!(:document) { create(:document, :finalized, entity: entity, department: department, sender: sender, addressee: addressee) }

    before do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      sign_in user
    end

    it "offers a Classify... trigger that opens the picker modal for the document" do
      get entity_documents_path(entity)

      expect(response.body).to include(classify_form_entity_document_path(entity, document))
    end
  end
end
