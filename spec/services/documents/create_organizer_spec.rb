# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::CreateOrganizer do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:sender) { create(:contact, entity: entity) }
  let(:addressee) { create(:contact, entity: entity) }

  let(:document_params) do
    {
      subject: "Contrat de prestation",
      document_date: Date.current,
      sender_id: sender.id,
      addressee_id: addressee.id
    }
  end

  describe ".call" do
    context "avec des paramètres valides" do
      it "crée le document scopé à l'entité" do
        expect {
          described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.to change(Document, :count).by(1)

        document = entity.documents.last
        expect(document.entity).to eq(entity)
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
      let(:document_params) { { subject: "", document_date: nil, sender_id: sender.id, addressee_id: addressee.id } }

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
          sender_id: other_contact.id,
          addressee_id: addressee.id
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
  end
end
