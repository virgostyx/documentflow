# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::ApproveStepOrganizer do
  let(:document) { create(:document, :with_workflow, :in_progress) }

  before do
    document.workflow_steps.find_by(role: "RED")&.update!(status: "approved")
  end

  describe ".call" do
    context "quand l'utilisateur n'est pas l'acteur de l'étape" do
      let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }
      let(:other_user) { create(:user) }

      it "retourne un échec et ne change pas le statut de l'étape" do
        result = described_class.call(step: visa_step, current_user: other_user)

        expect(result).not_to be_success
        expect(visa_step.reload).to be_pending
      end
    end

    context "approbation d'une étape VISA séquentielle" do
      let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

      it "approuve l'étape" do
        described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(visa_step.reload).to be_approved
      end

      it "ne fait pas avancer le statut du document (toujours in_progress)" do
        described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(document.reload).to be_in_progress
      end

      it "fait passer l'étape courante à SIGN" do
        described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(document.reload.current_step.role).to eq("SIGN")
      end

      it "notifie l'acteur suivant" do
        sign_actor = document.workflow_steps.find_by(role: "SIGN").actor

        expect(NotificationJob).to receive(:perform_later).with(sign_actor.id, "action_required", document.id)

        described_class.call(step: visa_step, current_user: visa_step.actor)
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(step: visa_step, current_user: visa_step.actor)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "approbation d'étapes VISA en parallèle" do
      let(:document) { create(:document, :in_progress) }
      let(:first_visa) do
        create(:workflow_step, :visa, :parallel, document: document, order: 2, parallel_group: 1, actor: create(:user))
      end
      let(:second_visa) do
        create(:workflow_step, :visa, :parallel, document: document, order: 3, parallel_group: 1, actor: create(:user))
      end

      before do
        create(:workflow_step, :red, document: document, order: 1, status: "approved", actor: document.created_by)
        create(:workflow_step, :sign, document: document, order: 4, actor: create(:user))
        create(:workflow_step, :exp, document: document, order: 5, actor: create(:user))
        first_visa
        second_visa
      end

      it "ne fait pas avancer tant que toutes les étapes parallèles ne sont pas approuvées" do
        allow(NotificationJob).to receive(:perform_later)

        described_class.call(step: first_visa, current_user: first_visa.actor)

        expect(second_visa.reload).to be_pending
        expect(document.reload).to be_in_progress
        expect(NotificationJob).not_to have_received(:perform_later)
      end

      it "avance dès que la dernière étape parallèle est approuvée" do
        described_class.call(step: first_visa, current_user: first_visa.actor)
        described_class.call(step: second_visa, current_user: second_visa.actor)

        expect(document.reload.current_step.role).to eq("SIGN")
      end
    end

    context "approbation de l'étape SIGN" do
      let(:sign_step) { document.workflow_steps.find_by(role: "SIGN") }

      before { document.workflow_steps.find_by(role: "VISA").update!(status: "approved") }

      it "fait passer le document au statut signed" do
        described_class.call(step: sign_step, current_user: sign_step.actor)

        expect(document.reload).to be_signed
      end

      it "fait passer l'étape courante à EXP" do
        described_class.call(step: sign_step, current_user: sign_step.actor)

        expect(document.reload.current_step.role).to eq("EXP")
      end
    end

    context "approbation de la dernière étape EXP (fin du circuit)" do
      let(:exp_step) { document.workflow_steps.find_by(role: "EXP") }

      before do
        document.workflow_steps.where(role: %w[VISA SIGN]).find_each { |s| s.update!(status: "approved") }
        document.update!(status: "signed")
      end

      it "finalise le document (gelé et statut finalized)" do
        described_class.call(step: exp_step, current_user: exp_step.actor)

        document.reload
        expect(document).to be_finalized
        expect(document.frozen?).to be true
      end
    end
  end
end
