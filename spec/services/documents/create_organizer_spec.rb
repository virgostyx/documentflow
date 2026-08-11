# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::CreateOrganizer do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:user) { create(:user) }
  let(:sender) { create(:contact, entity: entity) }
  let(:addressee) { create(:contact, entity: entity) }

  let!(:entity_user) do
    eu = create(:entity_user, entity: entity, user: user, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let(:document_params) do
    {
      subject: "Contrat de prestation",
      document_date: Date.current,
      department_id: department.id,
      sender_token: "Contact-#{sender.id}",
      addressee_token: "Contact-#{addressee.id}"
    }
  end

  describe ".call" do
    context "avec des paramètres valides" do
      it "crée le document scopé à l'entité et au département" do
        expect {
          described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.to change(Document, :count).by(1)

        document = entity.documents.last
        expect(document.entity).to eq(entity)
        expect(document.department).to eq(department)
        expect(document.created_by).to eq(user)
        expect(document.status).to eq("draft")
      end

      it "retourne le document créé dans le contexte" do
        result = described_class.call(entity: entity, current_user: user, document_params: document_params)

        expect(result).to be_success
        expect(result.document).to be_a(Document)
        expect(result.document.subject).to eq("Contrat de prestation")
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "avec des paramètres invalides" do
      let(:document_params) do
        { subject: "", document_date: nil, department_id: department.id,
          sender_token: "Contact-#{sender.id}", addressee_token: "Contact-#{addressee.id}" }
      end

      it "ne crée pas de document" do
        expect {
          described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.not_to change(Document, :count)
      end

      it "retourne un échec avec un message d'erreur" do
        result = described_class.call(entity: entity, current_user: user, document_params: document_params)

        expect(result).not_to be_success
        expect(result.message).to be_present
      end
    end

    context "quand le contact n'appartient pas à l'entité" do
      let(:other_contact) { create(:contact) }
      let(:document_params) do
        {
          subject: "Contrat de prestation",
          document_date: Date.current,
          department_id: department.id,
          sender_token: "Contact-#{other_contact.id}",
          addressee_token: "Contact-#{addressee.id}"
        }
      end

      it "ne crée pas de document et retourne un échec" do
        result = nil
        expect {
          result = described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.not_to change(Document, :count)

        expect(result).not_to be_success
      end
    end

    context "quand l'utilisateur n'appartient pas au département sélectionné" do
      let(:other_department) { create(:department, entity: entity) }
      let(:document_params) do
        {
          subject: "Contrat de prestation",
          document_date: Date.current,
          department_id: other_department.id,
          sender_token: "Contact-#{sender.id}",
          addressee_token: "Contact-#{addressee.id}"
        }
      end

      it "ne crée pas de document et retourne un message explicite" do
        result = nil
        expect {
          result = described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.not_to change(Document, :count)

        expect(result).not_to be_success
        expect(result.message).to include("not a member of the selected department")
      end
    end

    context "quand l'utilisateur est owner et n'appartient à aucun département" do
      let(:owner) { create(:user) }
      let!(:owner_entity_user) { create(:entity_user, :owner, entity: entity, user: owner) }

      it "crée tout de même le document" do
        expect {
          described_class.call(entity: entity, current_user: owner, document_params: document_params)
        }.to change(Document, :count).by(1)
      end
    end

    context "with a distribution_list_id in the params" do
      let(:distribution_list) { create(:distribution_list, user: user) }
      let(:cc_party) { create(:contact, entity: entity) }

      let(:document_params) do
        {
          subject: "Contrat de prestation",
          document_date: Date.current,
          department_id: department.id,
          sender_token: "Contact-#{sender.id}",
          addressee_token: "Contact-#{addressee.id}",
          distribution_list_id: distribution_list.id
        }
      end

      before do
        create(:distribution_list_member, distribution_list: distribution_list, party: addressee, position: 1)
        create(:distribution_list_member, distribution_list: distribution_list, party: cc_party, position: 2)
      end

      it "adds the non-addressee members as cc_recipients" do
        described_class.call(entity: entity, current_user: user, document_params: document_params)

        document = entity.documents.last
        expect(document.cc_recipients.map(&:party)).to contain_exactly(cc_party)
      end

      it "does not add the addressee itself as a cc_recipient" do
        described_class.call(entity: entity, current_user: user, document_params: document_params)

        document = entity.documents.last
        expect(document.cc_recipients.map(&:party)).not_to include(addressee)
      end
    end

    context "without a distribution_list_id" do
      it "does not add any cc_recipients" do
        described_class.call(entity: entity, current_user: user, document_params: document_params)

        document = entity.documents.last
        expect(document.cc_recipients).to be_empty
      end
    end

    context "with a distribution_list_id that does not belong to the current user" do
      let(:other_user) { create(:user) }
      let(:distribution_list) { create(:distribution_list, user: other_user) }
      let(:document_params) do
        {
          subject: "Contrat de prestation",
          document_date: Date.current,
          department_id: department.id,
          sender_token: "Contact-#{sender.id}",
          addressee_token: "Contact-#{addressee.id}",
          distribution_list_id: distribution_list.id
        }
      end

      before { create(:distribution_list_member, distribution_list: distribution_list, party: addressee, position: 1) }

      it "ignores the list and creates the document without extra cc_recipients" do
        result = described_class.call(entity: entity, current_user: user, document_params: document_params)

        expect(result).to be_success
        expect(result.document.cc_recipients).to be_empty
      end
    end
  end
end
