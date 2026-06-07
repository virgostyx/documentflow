# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::LaunchOrganizer do
  let(:user) { create(:user) }
  let(:document) { create(:document, :with_workflow, created_by: user) }

  describe ".call" do
    context "quand le document est en draft avec un circuit de validation" do
      it "passe le document en in_progress" do
        expect {
          described_class.call(document: document, current_user: user)
        }.to change { document.reload.status }.from("draft").to("in_progress")
      end

      it "approuve l'étape RED (le rédacteur a terminé son brouillon)" do
        described_class.call(document: document, current_user: user)

        red_step = document.workflow_steps.find_by(role: "RED")
        expect(red_step.reload).to be_approved
      end

      it "fait passer l'étape courante à la première étape VISA" do
        described_class.call(document: document, current_user: user)

        expect(document.reload.current_step.role).to eq("VISA")
      end

      it "notifie le premier acteur (le validateur VISA)" do
        visa_actor = document.workflow_steps.find_by(role: "VISA").actor

        expect(NotificationJob).to receive(:perform_later).with(visa_actor.id, "action_required", document.id)

        described_class.call(document: document, current_user: user)
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(document: document, current_user: user)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "quand le document n'a pas de circuit de validation" do
      let(:document) { create(:document, created_by: user) }

      it "retourne un échec explicite et ne change pas le statut" do
        result = described_class.call(document: document, current_user: user)

        expect(result).not_to be_success
        expect(result.message).to include("circuit de validation")
        expect(document.reload.status).to eq("draft")
      end
    end

    context "quand le document n'est pas en draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, created_by: user) }

      it "retourne un échec" do
        result = described_class.call(document: document, current_user: user)

        expect(result).not_to be_success
      end
    end
  end
end
