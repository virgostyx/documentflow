# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::ApproveStepOrganizer do
  let(:document) { create(:document, :with_workflow, :in_progress) }

  before do
    document.workflow_steps.find_by(role: "RED")&.update!(status: "approved")
  end

  def step_up_params_for(step)
    token = SecureRandom.hex(32)
    {
      step_up_token: token,
      step_up_tokens: { step.id.to_s => { "token" => token, "expires_at" => 2.minutes.from_now.to_i } }
    }
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

      it "diffuse la mise à jour de la sidebar à l'acteur suivant" do
        sign_actor = document.workflow_steps.find_by(role: "SIGN").actor

        expect(SidebarBroadcastJob).to receive(:perform_later).with(sign_actor.id, document.entity_id)

        described_class.call(step: visa_step, current_user: visa_step.actor)
      end

      it "diffuse la mise à jour de la carte de circuit à l'acteur suivant" do
        sign_actor = document.workflow_steps.find_by(role: "SIGN").actor

        expect(WorkflowStepsBroadcastJob).to receive(:perform_later).with(sign_actor.id, document.id)

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

      before do
        document.workflow_steps.find_by(role: "VISA").update!(status: "approved")
        create(:signature_image, user: sign_step.actor)
      end

      it "fait passer le document au statut signed" do
        described_class.call(step: sign_step, current_user: sign_step.actor, **step_up_params_for(sign_step))

        expect(document.reload).to be_signed
      end

      it "fait passer l'étape courante à EXP" do
        described_class.call(step: sign_step, current_user: sign_step.actor, **step_up_params_for(sign_step))

        expect(document.reload.current_step.role).to eq("EXP")
      end

      it "gèle le document" do
        described_class.call(step: sign_step, current_user: sign_step.actor, **step_up_params_for(sign_step))

        expect(document.reload.frozen?).to be true
      end

      it "planifie la conversion PDF" do
        expect(PdfConversionJob).to receive(:perform_later).with(document.id, sign_step.id)

        described_class.call(step: sign_step, current_user: sign_step.actor, **step_up_params_for(sign_step))
      end

      it "records the approving actor's IP and user agent when a request is provided" do
        request = instance_double(ActionDispatch::Request, remote_ip: "203.0.113.5", user_agent: "TestAgent/1.0")

        described_class.call(step: sign_step, current_user: sign_step.actor, request: request, **step_up_params_for(sign_step))

        expect(sign_step.reload.ip_address).to eq("203.0.113.5")
        expect(sign_step.reload.user_agent).to eq("TestAgent/1.0")
      end

      context "without a registered signature image" do
        before do
          sign_step.actor.signature_image.destroy!
          sign_step.actor.association(:signature_image).reset
        end

        it "fails and does not approve the step" do
          result = described_class.call(step: sign_step, current_user: sign_step.actor, **step_up_params_for(sign_step))

          expect(result).not_to be_success
          expect(sign_step.reload).to be_pending
        end
      end

      context "without a step-up token" do
        it "fails and does not approve the step" do
          result = described_class.call(step: sign_step, current_user: sign_step.actor)

          expect(result).not_to be_success
          expect(sign_step.reload).to be_pending
        end
      end

      context "with an expired step-up token" do
        it "fails and does not approve the step" do
          token = "expired-token"
          result = described_class.call(
            step: sign_step, current_user: sign_step.actor,
            step_up_token: token,
            step_up_tokens: { sign_step.id.to_s => { "token" => token, "expires_at" => 1.minute.ago.to_i } }
          )

          expect(result).not_to be_success
          expect(sign_step.reload).to be_pending
        end
      end

      context "with a step-up token minted for a different step" do
        it "fails and does not approve the step" do
          other_step = create(:workflow_step, :sign, document: document, order: 99, actor: sign_step.actor)
          result = described_class.call(step: sign_step, current_user: sign_step.actor, **step_up_params_for(other_step))

          expect(result).not_to be_success
          expect(sign_step.reload).to be_pending
        end
      end

      context "with a mismatched token value" do
        it "fails and does not approve the step" do
          valid_params = step_up_params_for(sign_step)
          result = described_class.call(
            step: sign_step, current_user: sign_step.actor,
            step_up_token: "wrong-token",
            step_up_tokens: valid_params[:step_up_tokens]
          )

          expect(result).not_to be_success
          expect(sign_step.reload).to be_pending
        end
      end
    end

    context "a circuit with two sequential (non-parallel) SIGN stages" do
      let(:document) { create(:document, :in_progress) }
      let(:first_signer) { create(:user) }
      let(:second_signer) { create(:user) }
      let(:first_sign_step) { create(:workflow_step, :sign, document: document, order: 3, actor: first_signer) }
      let(:second_sign_step) { create(:workflow_step, :sign, document: document, order: 4, actor: second_signer) }

      before do
        create(:workflow_step, :red, document: document, order: 1, status: "approved", actor: document.created_by)
        create(:workflow_step, :visa, document: document, order: 2, status: "approved", actor: create(:user))
        first_sign_step
        second_sign_step
        create(:workflow_step, :exp, document: document, order: 5, actor: create(:user))
        create(:signature_image, user: first_signer)
        create(:signature_image, user: second_signer)
      end

      it "schedules PDF conversion for the first SIGN stage" do
        expect(PdfConversionJob).to receive(:perform_later).with(document.id, first_sign_step.id)

        described_class.call(step: first_sign_step, current_user: first_signer, **step_up_params_for(first_sign_step))
      end

      it "also schedules PDF conversion for the second SIGN stage" do
        allow(PdfConversionJob).to receive(:perform_later)
        described_class.call(step: first_sign_step, current_user: first_signer, **step_up_params_for(first_sign_step))

        expect(PdfConversionJob).to receive(:perform_later).with(document.id, second_sign_step.id)

        described_class.call(step: second_sign_step, current_user: second_signer, **step_up_params_for(second_sign_step))
      end

      it "only transitions the document to signed once" do
        allow(PdfConversionJob).to receive(:perform_later)
        described_class.call(step: first_sign_step, current_user: first_signer, **step_up_params_for(first_sign_step))
        expect(document.reload).to be_signed

        described_class.call(step: second_sign_step, current_user: second_signer, **step_up_params_for(second_sign_step))

        expect(document.reload).to be_signed
      end
    end

    context "RED/VISA/EXP approvals require neither a signature image nor a step-up token" do
      it "approves a VISA step with no step_up_token/step_up_tokens passed at all" do
        visa_step = document.workflow_steps.find_by(role: "VISA")

        result = described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(result).to be_success
        expect(visa_step.reload).to be_approved
      end
    end

    context "approbation de la dernière étape EXP (fin du circuit)" do
      let(:exp_step) { document.workflow_steps.find_by(role: "EXP") }

      before do
        document.workflow_steps.where(role: %w[VISA SIGN]).find_each { |s| s.update!(status: "approved") }
        document.sign!
      end

      it "finalise le document (gelé et statut finalized)" do
        described_class.call(step: exp_step, current_user: exp_step.actor, dispatch_message: "Test message")

        document.reload
        expect(document).to be_finalized
        expect(document.frozen?).to be true
      end
    end

    context "approving EXP with a per-recipient dispatch preference" do
      let(:exp_step) { document.workflow_steps.find_by(role: "EXP") }
      let(:internal_user) do
        user = create(:user)
        create(:entity_user, entity: document.entity, user: user, status: "active")
        user
      end

      before do
        document.workflow_steps.where(role: %w[VISA SIGN]).find_each { |s| s.update!(status: "approved") }
        document.sign!
      end

      it "records the addressee's attachment preference when the addressee is external" do
        described_class.call(
          step: exp_step, current_user: exp_step.actor,
          addressee_dispatch_as_attachment: "true", dispatch_message: "Test message"
        )

        expect(document.reload.addressee_dispatch_as_attachment).to be true
      end

      it "defaults the addressee's attachment preference to false when unchecked" do
        described_class.call(step: exp_step, current_user: exp_step.actor, dispatch_message: "Test message")

        expect(document.reload.addressee_dispatch_as_attachment).to be false
      end

      it "does not touch the addressee preference when the addressee is internal" do
        document.update!(addressee: internal_user)

        described_class.call(
          step: exp_step, current_user: exp_step.actor,
          addressee_dispatch_as_attachment: "true", dispatch_message: "Test message"
        )

        expect(document.reload.addressee_dispatch_as_attachment).to be false
      end

      it "records the attachment preference only for the checked external cc recipients" do
        checked_cc = create(:cc_recipient, document: document, party: create(:contact, entity: document.entity))
        unchecked_cc = create(:cc_recipient, document: document, party: create(:contact, entity: document.entity))
        internal_cc = create(:cc_recipient, document: document, party: internal_user)

        described_class.call(
          step: exp_step, current_user: exp_step.actor,
          cc_dispatch_as_attachment_ids: [ checked_cc.id.to_s ], dispatch_message: "Test message"
        )

        expect(checked_cc.reload.dispatch_as_attachment).to be true
        expect(unchecked_cc.reload.dispatch_as_attachment).to be false
        expect(internal_cc.reload.dispatch_as_attachment).to be false
      end

      it "does not set any dispatch preference for a non-EXP step" do
        other_document = create(:document, :with_workflow, :in_progress)
        other_document.workflow_steps.find_by(role: "RED").update!(status: "approved")
        visa_step = other_document.workflow_steps.find_by(role: "VISA")

        described_class.call(step: visa_step, current_user: visa_step.actor, addressee_dispatch_as_attachment: "true")

        expect(other_document.reload.addressee_dispatch_as_attachment).to be false
      end

      it "records the include_attachment_note preference when checked" do
        described_class.call(
          step: exp_step, current_user: exp_step.actor,
          include_attachment_note: "true", dispatch_message: "Test message"
        )

        expect(document.reload.include_attachment_note).to be true
      end

      it "sets include_attachment_note to false when unchecked" do
        described_class.call(step: exp_step, current_user: exp_step.actor, dispatch_message: "Test message")

        expect(document.reload.include_attachment_note).to be false
      end

      it "does not touch include_attachment_note for a non-EXP step" do
        other_document = create(:document, :with_workflow, :in_progress)
        other_document.workflow_steps.find_by(role: "RED").update!(status: "approved")
        visa_step = other_document.workflow_steps.find_by(role: "VISA")

        described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(other_document.reload.include_attachment_note).to be true
      end
    end

    context "approving EXP with a dispatch message" do
      let(:exp_step) { document.workflow_steps.find_by(role: "EXP") }

      before do
        document.workflow_steps.where(role: %w[VISA SIGN]).find_each { |s| s.update!(status: "approved") }
        document.sign!
      end

      it "persists the submitted dispatch message" do
        described_class.call(step: exp_step, current_user: exp_step.actor, dispatch_message: "Please review before Friday.")

        expect(document.reload.dispatch_message).to eq("Please review before Friday.")
      end

      it "fails and does not approve the step when the message is blank" do
        result = described_class.call(step: exp_step, current_user: exp_step.actor, dispatch_message: "   ")

        expect(result).not_to be_success
        expect(exp_step.reload).to be_pending
      end

      it "fails and does not approve the step when no message is given at all" do
        result = described_class.call(step: exp_step, current_user: exp_step.actor)

        expect(result).not_to be_success
        expect(exp_step.reload).to be_pending
      end

      it "does not require a dispatch message for a non-EXP step" do
        other_document = create(:document, :with_workflow, :in_progress)
        other_document.workflow_steps.find_by(role: "RED").update!(status: "approved")
        visa_step = other_document.workflow_steps.find_by(role: "VISA")

        result = described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(result).to be_success
      end
    end

    context "après un rejet et retour à l'étape précédente" do
      let(:red_step) { document.workflow_steps.find_by(role: "RED") }
      let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

      before do
        Workflow::RejectStepOrganizer.call(step: visa_step, current_user: visa_step.actor, reason: "Pièce manquante")
      end

      it "remet VISA en pending au lieu de sauter directement à SIGN" do
        described_class.call(step: red_step.reload, current_user: red_step.actor)

        expect(visa_step.reload).to be_pending
        expect(document.reload.current_step).to eq(visa_step)
      end

      it "ne signe pas le document tant que VISA n'a pas été re-validée" do
        described_class.call(step: red_step.reload, current_user: red_step.actor)

        expect(document.reload).to be_in_progress
      end
    end

    context "when the document is checked out by another user" do
      let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

      before { document.update!(checked_out_by: create(:user), checked_out_at: Time.current) }

      it "fails and does not approve the step" do
        result = described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(result).not_to be_success
        expect(visa_step.reload).to be_pending
      end
    end

    context "when the document is checked out by the approving actor" do
      let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

      before { document.update!(checked_out_by: visa_step.actor, checked_out_at: Time.current) }

      it "still succeeds" do
        result = described_class.call(step: visa_step, current_user: visa_step.actor)

        expect(result).to be_success
        expect(visa_step.reload).to be_approved
      end
    end
  end
end
