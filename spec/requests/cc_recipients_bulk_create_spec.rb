# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CcRecipients#bulk_create", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }

  describe "POST /entities/:entity_id/documents/:document_id/cc_recipients/bulk_create" do
    let!(:document) { create(:document, entity: entity, created_by: user) }
    let(:contact_a) { create(:contact, entity: entity) }
    let(:contact_b) { create(:contact, entity: entity) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "adds every selected recipient in one request" do
        expect {
          post bulk_create_entity_document_cc_recipients_path(entity, document),
               params: { party_tokens: [ "Contact-#{contact_a.id}", "Contact-#{contact_b.id}" ] }
        }.to change(document.cc_recipients, :count).by(2)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end

      it "marks the document as multi_recipient" do
        post bulk_create_entity_document_cc_recipients_path(entity, document),
             params: { party_tokens: [ "Contact-#{contact_a.id}", "Contact-#{contact_b.id}" ] }

        expect(document.reload.multi_recipient).to be true
      end

      it "ignores blank tokens" do
        expect {
          post bulk_create_entity_document_cc_recipients_path(entity, document),
               params: { party_tokens: [ "Contact-#{contact_a.id}", "" ] }
        }.to change(document.cc_recipients, :count).by(1)
      end

      it "does not create any recipients and does not mark multi_recipient when a token is invalid" do
        outsider_contact = create(:contact, entity: create(:entity))

        expect {
          post bulk_create_entity_document_cc_recipients_path(entity, document),
               params: { party_tokens: [ "Contact-#{contact_a.id}", "Contact-#{outsider_contact.id}" ] }
        }.not_to change(document.cc_recipients, :count)

        expect(document.reload.multi_recipient).to be false
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "when the document is finalized" do
      let!(:document) { create(:document, :finalized, entity: entity, created_by: user) }

      before do
        create(:entity_user, :owner, entity: entity, user: user, status: "active")
        sign_in user
      end

      it "does not add recipients" do
        expect {
          post bulk_create_entity_document_cc_recipients_path(entity, document),
               params: { party_tokens: [ "Contact-#{contact_a.id}" ] }
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

      it "does not add recipients" do
        expect {
          post bulk_create_entity_document_cc_recipients_path(entity, document),
               params: { party_tokens: [ "Contact-#{contact_a.id}" ] }
        }.not_to change(document.cc_recipients, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
