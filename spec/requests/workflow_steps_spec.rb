# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkflowSteps", type: :request do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity) }

  before do
    document.workflow_steps.find_by(role: "RED")&.update!(status: "approved")
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/:id/approve" do
    let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

    context "as the step's actor" do
      before do
        create(:entity_user, entity: entity, user: visa_step.actor)
        sign_in visa_step.actor
      end

      it "approves the step" do
        post approve_entity_document_workflow_step_path(entity, document, visa_step)

        expect(visa_step.reload).to be_approved
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "as another user" do
      let(:other_user) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other_user)
        sign_in other_user
      end

      it "does not approve the step" do
        post approve_entity_document_workflow_step_path(entity, document, visa_step)

        expect(visa_step.reload).to be_pending
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        post approve_entity_document_workflow_step_path(entity, document, visa_step)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/workflow_steps/:id/confirm_reject" do
    let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

    context "as the step's actor" do
      before do
        create(:entity_user, entity: entity, user: visa_step.actor)
        sign_in visa_step.actor
      end

      it "renders the reject confirmation modal" do
        get confirm_reject_entity_document_workflow_step_path(entity, document, visa_step)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as another user" do
      let(:other_user) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other_user)
        sign_in other_user
      end

      it "redirects with an authorization error" do
        get confirm_reject_entity_document_workflow_step_path(entity, document, visa_step)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /entities/:entity_id/documents/:document_id/workflow_steps/:id/confirm_exp" do
    let(:exp_step) { document.workflow_steps.find_by(role: "EXP") }

    before do
      document.workflow_steps.where(role: %w[VISA SIGN]).find_each { |s| s.update!(status: "approved") }
      document.sign!
    end

    context "as the EXP step's actor" do
      before do
        create(:entity_user, entity: entity, user: exp_step.actor)
        sign_in exp_step.actor
      end

      it "renders the dispatch confirmation modal" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

        expect(response).to have_http_status(:ok)
      end

      it "pre-fills the message field with a default mentioning the document's reference and subject" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

        expect(response.body).to include("Document #{document.reload.reference_number} (#{document.subject}) has been finalized.")
      end

      it "pre-fills the message field with the document's previously saved dispatch message, if any" do
        document.update!(dispatch_message: "Please review the attached amendment before Friday.")

        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

        expect(response.body).to include("Please review the attached amendment before Friday.")
      end

      it "asks for confirmation before the Approve button actually dispatches, mentioning the recipient count" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

        expect(response.body).to include(
          "data-turbo-confirm=\"Dispatch this document to 1 recipient? This finalizes the document and cannot be undone.\""
        )
      end

      context "with cc recipients" do
        before do
          create(:cc_recipient, document: document, party: create(:contact, entity: entity))
          create(:cc_recipient, document: document, party: create(:contact, entity: entity))
        end

        it "mentions the total recipient count (addressee + cc recipients) in the confirmation" do
          get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

          expect(response.body).to include(
            "data-turbo-confirm=\"Dispatch this document to 3 recipients? This finalizes the document and cannot be undone.\""
          )
        end
      end

      context "when the document is multi_recipient" do
        before { document.update!(multi_recipient: true) }

        it "defaults the addressee's attachment checkbox to checked" do
          get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

          checkbox = Nokogiri::HTML(response.body).at_css("input[name='addressee_dispatch_as_attachment']")
          expect(checkbox["checked"]).to eq("checked")
        end
      end

      context "when the document is not multi_recipient" do
        it "leaves the addressee's attachment checkbox unchecked by default" do
          get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

          checkbox = Nokogiri::HTML(response.body).at_css("input[name='addressee_dispatch_as_attachment']")
          expect(checkbox["checked"]).to be_nil
        end
      end
    end

    context "as another user" do
      let(:other_user) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other_user)
        sign_in other_user
      end

      it "redirects with an authorization error" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

        expect(response).to redirect_to(root_path)
      end
    end

    context "when the targeted step is not EXP" do
      let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

      before do
        create(:entity_user, entity: entity, user: exp_step.actor)
        sign_in exp_step.actor
      end

      it "returns not found" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, visa_step)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an email template" do
      let!(:email_template) do
        create(:email_template, entity: entity, body_template: "Dear {{recipient_name}}, reference {{reference}}, issued {{date}}.")
      end
      let(:reference_field) { email_template.email_template_fields.find_by(tag_name: "reference") }

      before do
        create(:entity_user, entity: entity, user: exp_step.actor)
        sign_in exp_step.actor
      end

      it "shows the template picker" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step)

        expect(response.body).to include(email_template.name)
      end

      it "shows the template's fields once a template is selected" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step), params: { email_template_id: email_template.id }

        expect(response.body).to include(reference_field.label)
      end

      it "does not pre-fill the default finalized sentence once a template is selected" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step), params: { email_template_id: email_template.id }

        expect(response.body).not_to include("has been finalized.")
      end

      it "pre-fills the message with the rendered body, leaving {{recipient_name}} literal, when field values are submitted" do
        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step),
            params: { email_template_id: email_template.id, field_values: { "reference" => "TND-2026-01" }, generate_message: "1" }

        expect(response.body).to include("Dear {{recipient_name}}, reference TND-2026-01")
      end

      context "when the template has a subject_template" do
        let!(:email_template) do
          create(:email_template, entity: entity, subject_template: "Tender {{reference}}",
            body_template: "Dear {{recipient_name}}, reference {{reference}}, issued {{date}}.")
        end

        it "pre-fills the subject field with the rendered subject when field values are submitted" do
          get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step),
              params: { email_template_id: email_template.id, field_values: { "reference" => "TND-2026-01" }, generate_message: "1" }

          expect(response.body).to include(%(value="Tender TND-2026-01"))
        end
      end

      it "shows an error and does not overwrite the message when a required field is missing" do
        document.update!(dispatch_message: "Original message")

        get confirm_exp_entity_document_workflow_step_path(entity, document, exp_step),
            params: { email_template_id: email_template.id, field_values: {}, generate_message: "1" }

        expect(response.body).to include("Missing required field")
        expect(response.body).to include("Original message")
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/:id/approve with EXP dispatch preference" do
    let(:exp_step) { document.workflow_steps.find_by(role: "EXP") }

    before do
      document.workflow_steps.where(role: %w[VISA SIGN]).find_each { |s| s.update!(status: "approved") }
      document.sign!
      create(:entity_user, entity: entity, user: exp_step.actor)
      sign_in exp_step.actor
    end

    it "persists the addressee attachment preference from the submitted checkbox" do
      post approve_entity_document_workflow_step_path(entity, document, exp_step),
        params: { addressee_dispatch_as_attachment: "true", dispatch_message: "Test message" }

      expect(document.reload.addressee_dispatch_as_attachment).to be true
    end

    it "persists the checked cc recipients' attachment preference" do
      cc_recipient = create(:cc_recipient, document: document, party: create(:contact, entity: entity))

      post approve_entity_document_workflow_step_path(entity, document, exp_step),
        params: { cc_dispatch_as_attachment_ids: [ cc_recipient.id.to_s ], dispatch_message: "Test message" }

      expect(cc_recipient.reload.dispatch_as_attachment).to be true
    end

    it "persists the submitted dispatch message" do
      post approve_entity_document_workflow_step_path(entity, document, exp_step),
        params: { dispatch_message: "Please review the attached amendment before Friday." }

      expect(document.reload.dispatch_message).to eq("Please review the attached amendment before Friday.")
    end

    it "persists the submitted dispatch subject" do
      post approve_entity_document_workflow_step_path(entity, document, exp_step),
        params: { dispatch_message: "Test message", dispatch_subject: "Tender TND-2026-01" }

      expect(document.reload.dispatch_subject).to eq("Tender TND-2026-01")
    end

    it "does not require a dispatch subject (falls back to the default subject)" do
      post approve_entity_document_workflow_step_path(entity, document, exp_step),
        params: { dispatch_message: "Test message" }

      expect(exp_step.reload).to be_approved
      expect(document.reload.dispatch_subject).to be_blank
    end

    it "does not approve the step when the dispatch message is blank" do
      post approve_entity_document_workflow_step_path(entity, document, exp_step),
        params: { dispatch_message: "   " }

      expect(exp_step.reload).to be_pending
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/:id/reject" do
    let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }

    context "as the step's actor" do
      before do
        create(:entity_user, entity: entity, user: visa_step.actor)
        sign_in visa_step.actor
      end

      it "rejects the step with the given reason" do
        post reject_entity_document_workflow_step_path(entity, document, visa_step), params: { reason: "Missing signature" }

        expect(visa_step.reload).to be_rejected
        expect(visa_step.comment).to eq("Missing signature")
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "as the RED actor" do
      let(:red_step) { document.workflow_steps.find_by(role: "RED") }

      before do
        create(:entity_user, entity: entity, user: red_step.actor)
        sign_in red_step.actor
      end

      it "does not reject the step" do
        post reject_entity_document_workflow_step_path(entity, document, red_step), params: { reason: "Not convinced" }

        expect(red_step.reload).to be_approved
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "as another user" do
      let(:other_user) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other_user)
        sign_in other_user
      end

      it "does not reject the step" do
        post reject_entity_document_workflow_step_path(entity, document, visa_step), params: { reason: "Not convinced" }

        expect(visa_step.reload).to be_pending
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "adds a new step at the end of the circuit" do
        expect {
          post entity_document_workflow_steps_path(entity, document),
               params: { workflow_step: { role: "VISA" } }
        }.to change(document.workflow_steps, :count).by(1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present

        new_step = document.workflow_steps.order(:order).last
        expect(new_step.role).to eq("VISA")
        expect(new_step.order).to eq(1)
        expect(new_step).to be_pending
      end

      it "appends after existing steps" do
        create(:workflow_step, :red, document: document, order: 1)
        create(:workflow_step, :visa, document: document, order: 2)

        post entity_document_workflow_steps_path(entity, document),
             params: { workflow_step: { role: "SIGN" } }

        expect(document.workflow_steps.order(:order).last.order).to eq(3)
      end

      it "assigns the selected actor and parallel options" do
        colleague = create(:user)
        create(:entity_user, entity: entity, user: colleague, status: "active")

        post entity_document_workflow_steps_path(entity, document),
             params: { workflow_step: { role: "VISA", actor_id: colleague.id, is_parallel: "1", parallel_group: 1 } }

        new_step = document.workflow_steps.order(:order).last
        expect(new_step.actor).to eq(colleague)
        expect(new_step).to be_parallel
        expect(new_step.parallel_group).to eq(1)
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }

      before do
        create(:entity_user, :owner, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "does not add a step" do
        expect {
          post entity_document_workflow_steps_path(entity, document),
               params: { workflow_step: { role: "VISA" } }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest who is not the document's author" do
      let(:guest) { create(:user) }

      before do
        create(:entity_user, :guest, entity: entity, user: guest, status: "active")
        sign_in guest
      end

      it "does not add a step" do
        expect {
          post entity_document_workflow_steps_path(entity, document),
               params: { workflow_step: { role: "VISA" } }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /entities/:entity_id/documents/:document_id/workflow_steps/:id" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let!(:step) { create(:workflow_step, :red, document: document, order: 1) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "updates the step" do
        colleague = create(:user)
        create(:entity_user, entity: entity, user: colleague, status: "active")

        patch entity_document_workflow_step_path(entity, document, step),
              params: { workflow_step: { role: "VISA", actor_id: colleague.id } }

        expect(step.reload.role).to eq("VISA")
        expect(step.actor).to eq(colleague)
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
      let!(:step) { document.workflow_steps.find_by(role: "VISA") }

      before do
        create(:entity_user, :owner, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "does not update the step" do
        patch entity_document_workflow_step_path(entity, document, step),
              params: { workflow_step: { role: "SIGN" } }

        expect(step.reload.role).to eq("VISA")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /entities/:entity_id/documents/:document_id/workflow_steps/:id" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let!(:step) { create(:workflow_step, :red, document: document, order: 1) }

    context "as the document's author" do
      before do
        create(:entity_user, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "removes the step from the circuit" do
        expect {
          delete entity_document_workflow_step_path(entity, document, step)
        }.to change(document.workflow_steps, :count).by(-1)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
      let!(:step) { document.workflow_steps.find_by(role: "VISA") }

      before do
        create(:entity_user, :owner, entity: entity, user: author, status: "active")
        sign_in author
      end

      it "does not remove the step" do
        expect {
          delete entity_document_workflow_step_path(entity, document, step)
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /entities/:entity_id/documents/:document_id/workflow_steps/:id/reassign" do
    let(:visa_step) { document.workflow_steps.find_by(role: "VISA") }
    let(:new_actor) { create(:user) }

    context "as entity owner" do
      let(:owner) { create(:user) }

      before do
        create(:entity_user, :owner, entity: entity, user: owner, status: "active")
        create(:entity_user, entity: entity, user: new_actor, status: "active")
        sign_in owner
      end

      it "reassigns the step to the selected active member" do
        patch reassign_entity_document_workflow_step_path(entity, document, visa_step), params: { actor_id: new_actor.id }

        expect(visa_step.reload.actor).to eq(new_actor)
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
      end

      it "does not reassign to a user who is not an active member of the entity" do
        outsider = create(:user)

        patch reassign_entity_document_workflow_step_path(entity, document, visa_step), params: { actor_id: outsider.id }

        expect(visa_step.reload.actor).not_to eq(outsider)
        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "as the document's author" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
      let(:author) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: author, status: "active")
        create(:entity_user, entity: entity, user: new_actor, status: "active")
        sign_in author
      end

      it "reassigns the step" do
        patch reassign_entity_document_workflow_step_path(entity, document, visa_step), params: { actor_id: new_actor.id }

        expect(visa_step.reload.actor).to eq(new_actor)
      end
    end

    context "as a member without special rights" do
      let(:other_user) { create(:user) }

      before do
        create(:entity_user, entity: entity, user: other_user, status: "active")
        create(:entity_user, entity: entity, user: new_actor, status: "active")
        sign_in other_user
      end

      it "does not reassign the step" do
        patch reassign_entity_document_workflow_step_path(entity, document, visa_step), params: { actor_id: new_actor.id }

        expect(visa_step.reload.actor).not_to eq(new_actor)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when the step is not pending" do
      let(:owner) { create(:user) }
      let(:red_step) { document.workflow_steps.find_by(role: "RED") }

      before do
        create(:entity_user, :owner, entity: entity, user: owner, status: "active")
        create(:entity_user, entity: entity, user: new_actor, status: "active")
        sign_in owner
      end

      it "does not reassign an already approved step" do
        patch reassign_entity_document_workflow_step_path(entity, document, red_step), params: { actor_id: new_actor.id }

        expect(red_step.reload.actor).not_to eq(new_actor)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/apply_template" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let(:circuit_template) { create(:circuit_template, entity: entity) }

    before do
      create(:entity_user, entity: entity, user: author, status: "active")
      sign_in author
    end

    context "when the template has steps" do
      before do
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
        create(:circuit_template_step, circuit_template: circuit_template, role: "VISA", order: 2)
        create(:circuit_template_step, circuit_template: circuit_template, role: "SIGN", order: 3)
      end

      it "clones the template's steps into the document's circuit" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.to change(document.workflow_steps, :count).by(3)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:notice]).to be_present
        expect(document.workflow_steps.reload.ordered.pluck(:role)).to eq(%w[RED VISA SIGN])
      end

      it "continues the order numbering after existing steps" do
        create(:workflow_step, :red, document: document, order: 1)

        post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }

        expect(document.workflow_steps.reload.ordered.pluck(:order)).to eq([ 1, 2, 3, 4 ])
      end
    end

    context "when the template has no steps" do
      it "does not add any steps and shows an error" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(entity_document_path(entity, document))
        expect(flash[:alert]).to be_present
      end
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }

      before do
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
      end

      it "does not apply the template" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest who is not the document's author" do
      let(:guest) { create(:user) }

      before do
        create(:entity_user, :guest, entity: entity, user: guest, status: "active")
        sign_in guest
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
      end

      it "does not apply the template" do
        expect {
          post apply_template_entity_document_workflow_steps_path(entity, document), params: { circuit_template_id: circuit_template.id }
        }.not_to change(document.workflow_steps, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /entities/:entity_id/documents/:document_id/workflow_steps/:id/move_up and /move_down" do
    let(:author) { create(:user) }
    let(:document) { create(:document, entity: entity, created_by: author) }
    let!(:first_step) { create(:workflow_step, :red, document: document, order: 1) }
    let!(:second_step) { create(:workflow_step, :visa, document: document, order: 2) }

    before do
      create(:entity_user, entity: entity, user: author, status: "active")
      sign_in author
    end

    it "moves a step down, swapping its order with the next step" do
      post move_down_entity_document_workflow_step_path(entity, document, first_step)

      expect(response).to redirect_to(entity_document_path(entity, document))
      expect(flash[:notice]).to be_present
      expect(first_step.reload.order).to eq(2)
      expect(second_step.reload.order).to eq(1)
    end

    it "moves a step up, swapping its order with the previous step" do
      post move_up_entity_document_workflow_step_path(entity, document, second_step)

      expect(first_step.reload.order).to eq(2)
      expect(second_step.reload.order).to eq(1)
    end

    it "does nothing when moving the first step up" do
      post move_up_entity_document_workflow_step_path(entity, document, first_step)

      expect(first_step.reload.order).to eq(1)
      expect(second_step.reload.order).to eq(2)
    end

    context "when the document is not a draft" do
      let(:document) { create(:document, :with_workflow, :in_progress, entity: entity, created_by: author) }
      let!(:first_step) { document.workflow_steps.find_by(role: "RED") }
      let!(:second_step) { document.workflow_steps.find_by(role: "VISA") }

      it "does not move the step" do
        post move_down_entity_document_workflow_step_path(entity, document, first_step)

        expect(first_step.reload.order).to eq(1)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
