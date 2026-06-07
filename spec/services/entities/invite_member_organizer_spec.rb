# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entities::InviteMemberOrganizer do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let!(:owner_entity_user) { create(:entity_user, :owner, entity: entity, user: owner) }

  let(:params) do
    { entity: entity, current_user: owner, invited_email: "nouveau@example.com", role: "member" }
  end

  describe ".call" do
    context "avec un email qui n'est pas déjà membre" do
      it "crée un EntityUser en attente" do
        expect {
          described_class.call(**params)
        }.to change(EntityUser, :count).by(1)

        entity_user = entity.entity_users.find_by(invited_email: "nouveau@example.com")
        expect(entity_user).to be_pending
        expect(entity_user.role).to eq("member")
        expect(entity_user.invited_by).to eq(owner)
      end

      it "envoie un email d'invitation" do
        expect(InvitationMailer).to receive(:entity_invitation)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_later: true))

        described_class.call(**params)
      end

      it "retourne l'EntityUser créé dans le contexte" do
        result = described_class.call(**params)

        expect(result).to be_success
        expect(result.entity_user).to be_a(EntityUser)
        expect(result.entity_user.invited_email).to eq("nouveau@example.com")
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(**params)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "quand l'email est déjà membre ou invité" do
      before { create(:entity_user, :pending, entity: entity, invited_email: "nouveau@example.com", user: nil) }

      it "ne crée pas de nouvel EntityUser" do
        expect {
          described_class.call(**params)
        }.to change(EntityUser, :count).by(0)
      end

      it "retourne un échec avec un message explicite" do
        result = described_class.call(**params)

        expect(result).not_to be_success
        expect(result.message).to include("déjà")
      end
    end
  end
end
