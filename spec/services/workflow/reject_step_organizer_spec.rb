# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::RejectStepOrganizer do
  let(:document) { create(:document, :with_workflow, :in_progress) }
  let(:red_step)  { document.workflow_steps.find_by(role: "RED") }
  let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }
  let(:sign_step) { document.workflow_steps.find_by(role: "SIGN") }

  before { red_step.update!(status: "approved") }

  describe ".call" do
    context "quand l'acteur RED tente de rejeter" do
      it "retourne un échec" do
        result = described_class.call(step: red_step, current_user: red_step.actor, reason: "Pas convaincu")

        expect(result).not_to be_success
        expect(red_step.reload).to be_approved
      end
    end

    context "quand l'utilisateur n'est pas l'acteur de l'étape" do
      it "retourne un échec et ne change pas le statut" do
        result = described_class.call(step: visa_step, current_user: create(:user), reason: "Pas convaincu")

        expect(result).not_to be_success
        expect(visa_step.reload).to be_pending
      end
    end

    context "rejet d'une étape VISA" do
      it "marque l'étape comme rejetée avec le motif" do
        described_class.call(step: visa_step, current_user: visa_step.actor, reason: "Pièce manquante")

        visa_step.reload
        expect(visa_step).to be_rejected
        expect(visa_step.comment).to eq("Pièce manquante")
      end

      it "renvoie l'étape précédente (RED) en attente, qui redevient l'étape courante" do
        described_class.call(step: visa_step, current_user: visa_step.actor, reason: "Pièce manquante")

        red_step.reload
        expect(red_step).to be_pending
        expect(document.reload.current_step).to eq(red_step)
      end

      it "notifie l'acteur précédent du rejet avec le motif" do
        expect(NotificationJob).to receive(:perform_later)
          .with(red_step.actor.id, "rejection_alert", document.id, reason: "Pièce manquante")

        described_class.call(step: visa_step, current_user: visa_step.actor, reason: "Pièce manquante")
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(step: visa_step, current_user: visa_step.actor, reason: "Pièce manquante")
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "rejet d'une étape SIGN (renvoi vers VISA)" do
      before { visa_step.update!(status: "approved") }

      it "renvoie l'étape VISA précédente en attente" do
        described_class.call(step: sign_step, current_user: sign_step.actor, reason: "Signature illisible")

        visa_step.reload
        expect(visa_step).to be_pending
        expect(document.reload.current_step).to eq(visa_step)
      end
    end
  end
end
