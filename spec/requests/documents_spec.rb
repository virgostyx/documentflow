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
      let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Supplier contract") }

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

      it "wraps the results in a turbo frame targeted by the search form" do
        get entity_documents_path(entity)

        expect(response.body).to include('<turbo-frame id="documents_list"')
        expect(response.body).to include('data-turbo-frame="documents_list"')
      end

      it "filters by the search query" do
        other = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Annual report")

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
        older = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Older contract", document_date: 5.days.ago.to_date)
        newer = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Newer contract", document_date: Date.current)

        get entity_documents_path(entity)

        expect(response.body.index(newer.subject)).to be < response.body.index(older.subject)
      end

      it "sorts by an explicit column and direction" do
        alpha = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Alpha contract")
        beta = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Beta contract")

        get entity_documents_path(entity), params: { sort: "subject", direction: "asc" }

        expect(response.body.index(alpha.subject)).to be < response.body.index(beta.subject)
      end

      it "filters by status" do
        in_progress = create(:document, :in_progress, entity: entity, department: department, sender: sender, addressee: addressee, subject: "In progress contract")

        get entity_documents_path(entity), params: { status: "in_progress" }

        expect(response.body).to include(in_progress.subject)
        expect(response.body).not_to include(document.subject)
      end

      it "paginates the results" do
        allow(Kaminari.config).to receive(:default_per_page).and_return(1)
        create_list(:document, 2, entity: entity, department: department, sender: sender, addressee: addressee)

        get entity_documents_path(entity)

        expect(response.body).to include("page=2")
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
  end

  describe "GET /entities/:entity_id/documents/mine" do
    let!(:mine) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "My contract", created_by: user) }
    let!(:others_document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Colleague's contract") }

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
  end

  describe "GET /entities/:entity_id/documents/received" do
    let!(:received) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Routed to me") }
    let!(:not_received) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Not routed to me") }

    before do
      eu = create(:entity_user, entity: entity, user: user)
      create(:entity_user_department, entity_user: eu, department: department)
      create(:workflow_step, document: received, actor: user, status: "approved")
      create(:workflow_step, document: not_received, actor: create(:user))
      sign_in user
    end

    it "lists only documents where the current user is an actor on a workflow step, regardless of status" do
      get received_entity_documents_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(received.subject)
      expect(response.body).not_to include(not_received.subject)
    end
  end

  describe "GET /entities/:entity_id/documents/search" do
    let!(:document) { create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Supplier contract") }

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
      received = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Received supplier deal")
      other = create(:document, entity: entity, department: department, sender: sender, addressee: addressee, subject: "Other supplier deal")
      create(:workflow_step, document: received, actor: user)

      get search_entity_documents_path(entity), params: { q: "supplier", scope: "received" }

      expect(response.body).to include(received.subject)
      expect(response.body).not_to include(other.subject)
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
        expect(response.body).to include(document.reference_number)
        expect(response.body).to include(document.sender.full_name)
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
          delete entity_document_path(entity, document)
        }.to change(entity.documents, :count).by(-1)

        expect(response).to redirect_to(entity_documents_path(entity))
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
        post cancel_entity_document_path(entity, document)

        expect(document.reload).to be_cancelled
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
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
end
