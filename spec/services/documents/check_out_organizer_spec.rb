# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::CheckOutOrganizer do
  let(:document) { create(:document, :with_workflow, :in_progress) }
  let(:visa_actor) { document.workflow_steps.find_by(role: "VISA").actor }

  describe ".call" do
    context "when the document is not checked out" do
      it "checks out the document for the current user" do
        described_class.call(document: document, current_user: visa_actor)

        document.reload
        expect(document.checked_out_by).to eq(visa_actor)
        expect(document.checked_out_at).to be_present
      end

      it "returns a successful result" do
        result = described_class.call(document: document, current_user: visa_actor)

        expect(result).to be_success
      end

      it "logs an audit event" do
        expect {
          described_class.call(document: document, current_user: visa_actor)
        }.to change(AuditLog, :count).by(1)

        expect(AuditLog.last.action).to eq("check_out")
      end

      it "notifies the document's creator" do
        expect(NotificationJob).to receive(:perform_later).with(document.created_by.id, "checked_out", document.id)

        described_class.call(document: document, current_user: visa_actor)
      end
    end

    context "when the document's creator checks it out themself" do
      it "does not notify anyone" do
        expect(NotificationJob).not_to receive(:perform_later)

        described_class.call(document: document, current_user: document.created_by)
      end
    end

    context "when already checked out by the same user" do
      before { document.update!(checked_out_by: visa_actor, checked_out_at: 1.hour.ago) }

      it "succeeds without error" do
        result = described_class.call(document: document, current_user: visa_actor)

        expect(result).to be_success
      end
    end

    context "when already checked out by another user" do
      let(:other_user) { create(:user) }

      before { document.update!(checked_out_by: other_user, checked_out_at: 1.hour.ago) }

      it "fails and does not change the checkout" do
        result = described_class.call(document: document, current_user: visa_actor)

        expect(result).not_to be_success
        expect(document.reload.checked_out_by).to eq(other_user)
      end
    end
  end
end
