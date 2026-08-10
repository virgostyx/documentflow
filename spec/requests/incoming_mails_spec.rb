# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Incoming mails", type: :request do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:user) { create(:user) }
  let(:lead) { create(:user) }
  let(:sender) { create(:contact, entity: entity) }

  let!(:entity_user) do
    eu = create(:entity_user, entity: entity, user: user, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let!(:lead_entity_user) do
    eu = create(:entity_user, entity: entity, user: lead, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  describe "GET /entities/:entity_id/incoming_mails/new" do
    before { sign_in user }

    it "renders the registration form" do
      get new_entity_incoming_mail_path(entity)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /entities/:entity_id/incoming_mails" do
    before { sign_in user }

    let(:params) do
      {
        document: {
          subject: "Tax notice",
          document_date: Date.current,
          department_id: department.id,
          sender_token: "Contact-#{sender.id}",
          lead_user_id: lead.id
        }
      }
    end

    context "with valid params" do
      it "registers the incoming mail" do
        expect {
          post entity_incoming_mails_path(entity), params: params
        }.to change(Document, :count).by(1)

        document = entity.documents.incoming.last
        expect(document.lead_user).to eq(lead)
        expect(response).to redirect_to(entity_incoming_mail_path(entity, document))
      end
    end

    context "with invalid params" do
      let(:params) do
        { document: { subject: "", document_date: nil, department_id: department.id, sender_token: "Contact-#{sender.id}", lead_user_id: lead.id } }
      end

      it "does not register the mail and re-renders the form" do
        expect {
          post entity_incoming_mails_path(entity), params: params
        }.not_to change(Document, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with a main file and annexes" do
      let(:main_file) { fixture_file_upload("sample.pdf", "application/pdf") }
      let(:annex) { fixture_file_upload("sample.pdf", "application/pdf") }
      let(:params) do
        {
          document: {
            subject: "Tax notice",
            document_date: Date.current,
            department_id: department.id,
            sender_token: "Contact-#{sender.id}",
            lead_user_id: lead.id,
            main_file: main_file,
            annexes: [ annex ]
          }
        }
      end

      it "attaches the main file and annexes" do
        post entity_incoming_mails_path(entity), params: params

        document = entity.documents.incoming.last
        expect(document.main_file).to be_attached
        expect(document.annexes).to be_one
      end
    end

    context "with a blank annexes entry (as submitted by a multiple file_field with none chosen)" do
      let(:main_file) { fixture_file_upload("sample.pdf", "application/pdf") }
      let(:params) do
        {
          document: {
            subject: "Tax notice",
            document_date: Date.current,
            department_id: department.id,
            sender_token: "Contact-#{sender.id}",
            lead_user_id: lead.id,
            main_file: main_file,
            annexes: [ "" ]
          }
        }
      end

      it "does not create an annex for the blank entry" do
        post entity_incoming_mails_path(entity), params: params

        document = entity.documents.incoming.last
        expect(document.annexes).to be_empty
      end
    end
  end

  describe "GET /entities/:entity_id/incoming_mails/:id" do
    let!(:document) { create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead) }

    context "as the lead" do
      before { sign_in lead }

      it "shows the mail" do
        get entity_incoming_mail_path(entity, document)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(document.reference_number)
      end
    end

    context "as an unrelated department member" do
      let(:other_department) { create(:department, entity: entity) }
      let(:outsider) { create(:user) }

      before do
        eu = create(:entity_user, entity: entity, user: outsider, status: "active")
        create(:entity_user_department, entity_user: eu, department: other_department)
        sign_in outsider
      end

      it "redirects with an authorization error" do
        get entity_incoming_mail_path(entity, document)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/incoming_mails" do
    let!(:pending) { create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead, subject: "Needs triage") }
    let!(:routed) { create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead, routed_at: Time.current, subject: "Already routed") }
    let!(:not_lead) { create(:document, :incoming, entity: entity, department: department, subject: "Someone else's mail") }

    before { sign_in lead }

    it "lists incoming mail awaiting the current user's triage as lead" do
      get entity_incoming_mails_path(entity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pending.subject)
      expect(response.body).not_to include(routed.subject)
      expect(response.body).not_to include(not_lead.subject)
    end
  end

  describe "GET /entities/:entity_id/incoming_mails/:id/route_form" do
    let!(:document) { create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead) }

    context "as the lead" do
      before { sign_in lead }

      it "renders the routing form" do
        get route_form_entity_incoming_mail_path(entity, document)

        expect(response).to have_http_status(:ok)
      end

      it "does not show the Replies to field when there is no repliable original document" do
        get route_form_entity_incoming_mail_path(entity, document)

        expect(response.body).not_to include("Replies to")
      end

      context "when a repliable original document exists" do
        let!(:original) { create(:document, :finalized, :expecting_response, entity: entity, department: department, addressee: document.sender) }

        it "shows the Replies to field with the candidate" do
          get route_form_entity_incoming_mail_path(entity, document)

          expect(response.body).to include("Replies to")
          expect(response.body).to include(original.display_number)
        end
      end
    end

    context "as another department member who is not the lead" do
      before { sign_in user }

      it "redirects with an authorization error" do
        get route_form_entity_incoming_mail_path(entity, document)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /entities/:entity_id/incoming_mails/:id/route" do
    let!(:document) { create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead) }
    let(:info_user) do
      create(:user).tap do |u|
        eu = create(:entity_user, entity: entity, user: u, status: "active")
        create(:entity_user_department, entity_user: eu, department: department)
      end
    end

    let(:params) do
      {
        document: {
          action_user_id: user.id,
          routing_message: "Please handle this",
          expects_response: "1",
          response_deadline: (Date.current + 3.days).to_s,
          info_user_ids: [ info_user.id ]
        }
      }
    end

    context "as the lead" do
      before { sign_in lead }

      it "routes the mail" do
        patch route_entity_incoming_mail_path(entity, document), params: params

        document.reload
        expect(document.addressee).to eq(user)
        expect(document.routed_at).to be_present
        expect(response).to redirect_to(entity_incoming_mail_path(entity, document))
      end

      context "when linking to an original document" do
        let(:original) { create(:document, :finalized, :expecting_response, entity: entity, department: department) }
        let(:params) do
          { document: { action_user_id: user.id, expects_response: "0", in_reply_to_id: original.id } }
        end

        it "persists the link to the original document" do
          patch route_entity_incoming_mail_path(entity, document), params: params

          expect(document.reload.in_reply_to).to eq(original)
        end
      end
    end

    context "as another department member who is not the lead" do
      before { sign_in user }

      it "redirects with an authorization error and does not route the mail" do
        patch route_entity_incoming_mail_path(entity, document), params: params

        expect(document.reload.routed_at).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
