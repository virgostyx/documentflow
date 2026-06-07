# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entities::CreateOrganizer do
  let(:user) { create(:user) }
  let(:entity_params) { { name: "Acme Corp" } }

  describe ".call" do
    context "avec des paramètres valides" do
      it "crée l'entité" do
        expect {
          described_class.call(current_user: user, entity_params: entity_params)
        }.to change(Entity, :count).by(1)
      end

      it "crée un EntityUser owner actif pour le créateur" do
        result = described_class.call(current_user: user, entity_params: entity_params)

        entity_user = result.entity.entity_users.find_by(user: user)
        expect(entity_user).to be_present
        expect(entity_user).to be_owner
        expect(entity_user).to be_active
      end

      it "retourne l'entité créée dans le contexte" do
        result = described_class.call(current_user: user, entity_params: entity_params)

        expect(result).to be_success
        expect(result.entity).to be_a(Entity)
        expect(result.entity.name).to eq("Acme Corp")
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(current_user: user, entity_params: entity_params)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "avec des paramètres invalides" do
      let(:entity_params) { { name: "" } }

      it "ne crée ni entité ni EntityUser" do
        expect {
          described_class.call(current_user: user, entity_params: entity_params)
        }.to change(Entity, :count).by(0).and change(EntityUser, :count).by(0)
      end

      it "retourne un échec avec un message d'erreur" do
        result = described_class.call(current_user: user, entity_params: entity_params)

        expect(result).not_to be_success
        expect(result.message).to be_present
      end
    end
  end
end
