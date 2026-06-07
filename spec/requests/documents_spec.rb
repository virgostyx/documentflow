# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Documents", type: :request do
  let(:entity) { create(:entity) }
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
      let!(:document) { create(:document, entity: entity, sender: sender, addressee: addressee, subject: "Supplier contract") }

      before do
        create(:entity_user, entity: entity, user: user)
        sign_in user
      end

      it "lists the entity's documents" do
        get entity_documents_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document.subject)
      end

      it "filters by the search query" do
        other = create(:document, entity: entity, sender: sender, addressee: addressee, subject: "Annual report")

        get entity_documents_path(entity), params: { q: "Supplier" }

        expect(response.body).to include(document.subject)
        expect(response.body).not_to include(other.subject)
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

  describe "GET /entities/:entity_id/documents/search" do
    let!(:document) { create(:document, entity: entity, sender: sender, addressee: addressee, subject: "Supplier contract") }

    before do
      create(:entity_user, entity: entity, user: user)
      sign_in user
    end

    it "renders the filtered list" do
      get search_entity_documents_path(entity), params: { q: "Supplier" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(document.subject)
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
              sender_id: sender.id,
              addressee_id: addressee.id
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
      end

      context "with a validation circuit" do
        let(:red_actor) { user }
        let(:visa_actor) { create(:user) }
        let(:document_params) do
          {
            document: {
              subject: "New supplier agreement",
              document_date: Date.current,
              sender_id: sender.id,
              addressee_id: addressee.id,
              workflow_steps_attributes: {
                "0" => { role: "RED", order: 1, actor_id: red_actor.id },
                "1" => { role: "VISA", order: 2, actor_id: visa_actor.id }
              }
            }
          }
        end

        before do
          create(:entity_user, entity: entity, user: visa_actor)
        end

        it "creates the document with its validation circuit" do
          post entity_documents_path(entity), params: document_params

          document = entity.documents.find_by(subject: "New supplier agreement")
          expect(document.workflow_steps.ordered.pluck(:role)).to eq(%w[RED VISA])
          expect(document.workflow_steps.find_by(role: "VISA").actor).to eq(visa_actor)
        end
      end

      context "with invalid params" do
        let(:document_params) do
          { document: { subject: "", document_date: nil, sender_id: sender.id, addressee_id: addressee.id } }
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
    end

    context "when the user is a guest" do
      let(:document_params) do
        { document: { subject: "Sneaky", document_date: Date.current, sender_id: sender.id, addressee_id: addressee.id } }
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
    let!(:document) { create(:document, entity: entity, sender: sender, addressee: addressee) }

    context "when the user is an active member" do
      before do
        create(:entity_user, entity: entity, user: user)
        sign_in user
      end

      it "shows the document" do
        get entity_document_path(entity, document)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document.reference_number)
        expect(response.body).to include(document.sender.full_name)
      end

      context "when the document has a validation circuit" do
        let!(:document) { create(:document, :with_workflow, :in_progress, entity: entity, sender: sender, addressee: addressee) }

        it "displays the workflow steps" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Validation circuit")
          expect(response.body).to include("RED")
          expect(response.body).to include("VISA")
        end
      end

      context "as the current step's actor" do
        let!(:document) { create(:document, :with_workflow, :in_progress, entity: entity, sender: sender, addressee: addressee, created_by: user) }

        before { document.workflow_steps.find_by(role: "RED").update!(actor: user) }

        it "displays the approve action button" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Approve")
        end
      end
    end

    context "public sharing" do
      context "when the document is finalized" do
        let!(:document) { create(:document, :finalized, entity: entity, sender: sender, addressee: addressee) }
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
        let!(:document) { create(:document, :in_progress, entity: entity, sender: sender, addressee: addressee) }

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
    let!(:document) { create(:document, entity: entity, sender: sender, addressee: addressee, created_by: user) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user)
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
        create(:entity_user, entity: entity, user: other)
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
    let!(:document) { create(:document, entity: entity, sender: sender, addressee: addressee, created_by: user, subject: "Old subject") }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user)
        sign_in user
      end

      it "updates the document" do
        patch entity_document_path(entity, document), params: { document: { subject: "New subject" } }

        expect(document.reload.subject).to eq("New subject")
        expect(response).to redirect_to(entity_document_path(entity, document))
      end

      context "with validation circuit changes" do
        let!(:red_step) { create(:workflow_step, :red, document: document, order: 1, actor: user) }
        let(:visa_actor) { create(:user) }

        before { create(:entity_user, entity: entity, user: visa_actor) }

        it "adds new steps to the circuit" do
          patch entity_document_path(entity, document), params: {
            document: {
              workflow_steps_attributes: {
                "0" => { id: red_step.id, role: "RED", order: 1, actor_id: user.id },
                "1" => { role: "VISA", order: 2, actor_id: visa_actor.id }
              }
            }
          }

          expect(document.reload.workflow_steps.ordered.pluck(:role)).to eq(%w[RED VISA])
        end

        it "removes steps marked for destruction" do
          visa_step = create(:workflow_step, :visa, document: document, order: 2, actor: visa_actor)

          patch entity_document_path(entity, document), params: {
            document: {
              workflow_steps_attributes: {
                "0" => { id: red_step.id, role: "RED", order: 1, actor_id: user.id },
                "1" => { id: visa_step.id, _destroy: "1" }
              }
            }
          }

          expect(document.reload.workflow_steps.pluck(:role)).to eq(%w[RED])
        end
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:id" do
    let!(:document) { create(:document, entity: entity, sender: sender, addressee: addressee, created_by: user) }

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
        create(:entity_user, entity: entity, user: user)
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
      let!(:document) { create(:document, :with_workflow, entity: entity, sender: sender, addressee: addressee, created_by: user) }

      before do
        create(:entity_user, entity: entity, user: user)
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
      let!(:document) { create(:document, entity: entity, sender: sender, addressee: addressee, created_by: user) }

      before do
        create(:entity_user, entity: entity, user: user)
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
      let!(:document) { create(:document, :with_workflow, entity: entity, sender: sender, addressee: addressee, created_by: user) }
      let(:other) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other)
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
      let!(:document) { create(:document, :in_progress, entity: entity, sender: sender, addressee: addressee, created_by: user) }

      before do
        create(:entity_user, entity: entity, user: user)
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
      let!(:document) { create(:document, :finalized, entity: entity, sender: sender, addressee: addressee, created_by: user) }

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
