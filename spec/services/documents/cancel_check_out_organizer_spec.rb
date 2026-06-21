# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::CancelCheckOutOrganizer do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, :with_workflow, :in_progress, entity: entity) }
  let(:visa_actor) { document.workflow_steps.find_by(role: "VISA").actor }

  before { document.update!(checked_out_by: visa_actor, checked_out_at: 1.hour.ago) }

  describe ".call" do
    context "as the user who checked the document out" do
      it "releases the lock" do
        described_class.call(document: document, current_user: visa_actor)

        document.reload
        expect(document.checked_out_by).to be_nil
        expect(document.checked_out_at).to be_nil
      end

      it "does not create a document file version" do
        expect {
          described_class.call(document: document, current_user: visa_actor)
        }.not_to change(DocumentFileVersion, :count)
      end

      it "logs an audit event" do
        expect {
          described_class.call(document: document, current_user: visa_actor)
        }.to change(AuditLog, :count).by(1)

        expect(AuditLog.last.action).to eq("cancel_check_out")
      end
    end

    context "as an entity owner who did not check the document out" do
      let(:owner) { create(:user).tap { |u| create(:entity_user, :owner, user: u, entity: entity, status: "active") } }

      it "releases the lock" do
        described_class.call(document: document, current_user: owner)

        expect(document.reload.checked_out_by).to be_nil
      end
    end

    context "as an unrelated member" do
      let(:other_member) { create(:user).tap { |u| create(:entity_user, user: u, entity: entity, role: "member", status: "active") } }

      it "fails and does not release the lock" do
        result = described_class.call(document: document, current_user: other_member)

        expect(result).not_to be_success
        expect(document.reload.checked_out_by).to eq(visa_actor)
      end
    end

    context "when the document is not checked out" do
      before { document.update!(checked_out_by: nil, checked_out_at: nil) }

      it "fails" do
        result = described_class.call(document: document, current_user: visa_actor)

        expect(result).not_to be_success
      end
    end
  end
end
