# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Contacts", type: :request do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }

  describe "GET /entities/:entity_id/contacts" do
    context "when not signed in" do
      it "redirects to sign in" do
        get entity_contacts_path(entity)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user is an active member" do
      let!(:contact) { create(:contact, entity: entity, first_name: "Jean", last_name: "Dupont") }

      before do
        create(:entity_user, entity: entity, user: user)
        sign_in user
      end

      it "lists the entity's contacts" do
        get entity_contacts_path(entity)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(contact.full_name)
      end
    end

    context "when the user is not a member of the entity" do
      before { sign_in user }

      it "redirects to the dashboard with an access denied alert" do
        get entity_contacts_path(entity)

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /entities/:entity_id/contacts/new" do
    context "when the user is staff" do
      before do
        create(:entity_user, :admin, entity: entity, user: user)
        sign_in user
      end

      it "renders the new contact form" do
        get new_entity_contact_path(entity)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is a guest" do
      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        get new_entity_contact_path(entity)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/contacts" do
    before do
      create(:entity_user, :admin, entity: entity, user: user)
      sign_in user
    end

    context "with valid params" do
      let(:contact_params) do
        { contact: { first_name: "Marie", last_name: "Martin", email: "marie@example.com", company: "Acme", phone: "+32 2 000 00 00" } }
      end

      it "creates the contact" do
        expect {
          post entity_contacts_path(entity), params: contact_params
        }.to change(entity.contacts, :count).by(1)
      end

      it "redirects to the contacts list" do
        post entity_contacts_path(entity), params: contact_params

        expect(response).to redirect_to(entity_contacts_path(entity))
      end
    end

    context "with invalid params" do
      let(:contact_params) { { contact: { first_name: "", last_name: "Martin", email: "not-an-email" } } }

      it "does not create the contact" do
        expect {
          post entity_contacts_path(entity), params: contact_params
        }.not_to change(Contact, :count)
      end

      it "renders the new form again" do
        post entity_contacts_path(entity), params: contact_params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /entities/:entity_id/contacts/:id/edit" do
    let!(:contact) { create(:contact, entity: entity) }

    context "when the user is staff" do
      before do
        create(:entity_user, :admin, entity: entity, user: user)
        sign_in user
      end

      it "renders the edit form" do
        get edit_entity_contact_path(entity, contact)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is a guest" do
      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        get edit_entity_contact_path(entity, contact)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /entities/:entity_id/contacts/:id" do
    let!(:contact) { create(:contact, entity: entity, first_name: "Jean") }

    context "when the user is staff" do
      before do
        create(:entity_user, :admin, entity: entity, user: user)
        sign_in user
      end

      it "updates the contact" do
        patch entity_contact_path(entity, contact), params: { contact: { first_name: "Pierre" } }

        expect(contact.reload.first_name).to eq("Pierre")
        expect(response).to redirect_to(entity_contacts_path(entity))
      end
    end

    context "when the user is a guest" do
      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "redirects with an authorization error" do
        patch entity_contact_path(entity, contact), params: { contact: { first_name: "Pierre" } }

        expect(contact.reload.first_name).to eq("Jean")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/contacts/:id" do
    let!(:contact) { create(:contact, entity: entity) }

    context "when the user is staff" do
      before do
        create(:entity_user, :admin, entity: entity, user: user)
        sign_in user
      end

      it "destroys the contact" do
        expect {
          delete entity_contact_path(entity, contact)
        }.to change(entity.contacts, :count).by(-1)

        expect(response).to redirect_to(entity_contacts_path(entity))
      end
    end

    context "when the user is a guest" do
      before do
        create(:entity_user, :guest, entity: entity, user: user)
        sign_in user
      end

      it "does not destroy the contact" do
        expect {
          delete entity_contact_path(entity, contact)
        }.not_to change(Contact, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
