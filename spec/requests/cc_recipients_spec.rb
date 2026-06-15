# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CcRecipients", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }

  describe "POST /entities/:entity_id/documents/:document_id/cc_recipients" do
    let!(:document) { create(:document, entity: entity, created_by: user) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      context "with a valid contact" do
        let(:contact) { create(:contact, entity: entity) }

        it "adds the contact to the copy list" do
          expect {
            post entity_document_cc_recipients_path(entity, document),
                 params: { cc_recipient: { party_token: "Contact-#{contact.id}" } }
          }.to change(document.cc_recipients, :count).by(1)

          expect(response).to redirect_to(entity_document_path(entity, document))
          expect(flash[:notice]).to be_present
          expect(document.cc_recipients.last.party).to eq(contact)
        end
      end

      context "with an internal user" do
        let(:colleague) { create(:user) }

        before { create(:entity_user, entity: entity, user: colleague, status: "active") }

        it "adds the user to the copy list" do
          expect {
            post entity_document_cc_recipients_path(entity, document),
                 params: { cc_recipient: { party_token: "User-#{colleague.id}" } }
          }.to change(document.cc_recipients, :count).by(1)

          expect(document.cc_recipients.last.party).to eq(colleague)
        end
      end

      context "with a contact from another entity" do
        let(:other_contact) { create(:contact) }

        it "does not add the recipient and redirects with an alert" do
          expect {
            post entity_document_cc_recipients_path(entity, document),
                 params: { cc_recipient: { party_token: "Contact-#{other_contact.id}" } }
          }.not_to change(document.cc_recipients, :count)

          expect(response).to redirect_to(entity_document_path(entity, document))
          expect(flash[:alert]).to be_present
        end
      end
    end

    context "when the document is finalized" do
      let!(:document) { create(:document, :finalized, entity: entity, created_by: user) }
      let(:contact) { create(:contact, entity: entity) }

      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not add a recipient" do
        expect {
          post entity_document_cc_recipients_path(entity, document),
               params: { cc_recipient: { party_token: "Contact-#{contact.id}" } }
        }.not_to change(document.cc_recipients, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest who is not the document's author" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not add a recipient" do
        contact = create(:contact, entity: entity)

        expect {
          post entity_document_cc_recipients_path(entity, document),
               params: { cc_recipient: { party_token: "Contact-#{contact.id}" } }
        }.not_to change(document.cc_recipients, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:document_id/cc_recipients/:id" do
    let!(:document) { create(:document, entity: entity, created_by: user) }
    let!(:cc_recipient) { create(:cc_recipient, document: document) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "removes the recipient from the copy list" do
        expect {
          delete entity_document_cc_recipient_path(entity, document, cc_recipient)
        }.to change(document.cc_recipients, :count).by(-1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "as a guest who is not the document's author" do
      let!(:document) { create(:document, entity: entity, created_by: create(:user)) }

      before do
        create(:entity_user, :guest, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not remove the recipient" do
        expect {
          delete entity_document_cc_recipient_path(entity, document, cc_recipient)
        }.not_to change(document.cc_recipients, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
