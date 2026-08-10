# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomingMails::RouteOrganizer do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:lead) { create(:user) }
  let(:action_user) { create(:user) }
  let(:info_user) { create(:user) }

  let!(:lead_entity_user) do
    eu = create(:entity_user, entity: entity, user: lead, status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let!(:action_entity_user) do
    eu = create(:entity_user, entity: entity, user: action_user, status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let!(:info_entity_user) do
    eu = create(:entity_user, entity: entity, user: info_user, status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let(:document) do
    create(:document, :incoming, entity: entity, department: department, lead_user: lead, addressee: lead)
  end

  let(:routing_params) do
    {
      action_user_id: action_user.id,
      routing_message: "Please handle this by Friday",
      expects_response: true,
      response_deadline: Date.current + 5.days,
      info_user_ids: [ info_user.id ]
    }
  end

  describe ".call" do
    context "with valid params" do
      it "moves the addressee to the action user and stores the routing details" do
        described_class.call(document: document, current_user: lead, routing_params: routing_params)

        document.reload
        expect(document.addressee).to eq(action_user)
        expect(document.routing_message).to eq("Please handle this by Friday")
        expect(document.expects_response).to be true
        expect(document.response_deadline).to eq(Date.current + 5.days)
        expect(document.routed_at).to be_present
      end

      it "creates a cc_recipient for each info user" do
        expect {
          described_class.call(document: document, current_user: lead, routing_params: routing_params)
        }.to change(CcRecipient, :count).by(1)

        expect(document.cc_recipients.reload.map(&:party)).to contain_exactly(info_user)
      end

      it "returns success with the updated document" do
        result = described_class.call(document: document, current_user: lead, routing_params: routing_params)

        expect(result).to be_success
        expect(result.document).to eq(document)
      end

      it "notifies the action user and the info recipients" do
        expect(NotificationJob).to receive(:perform_later).with(action_user.id, "mail_action_assigned", document.id)
        expect(CcNotificationJob).to receive(:perform_later).with("User", info_user.id, document.id, lead.id)

        described_class.call(document: document, current_user: lead, routing_params: routing_params)
      end

      it "does not require a message or info recipients" do
        minimal_params = { action_user_id: action_user.id, expects_response: false, info_user_ids: [ "" ] }

        result = described_class.call(document: document, current_user: lead, routing_params: minimal_params)

        expect(result).to be_success
        expect(document.reload.routed_at).to be_present
      end

      it "clears the response_deadline when expects_response is false" do
        params = routing_params.merge(expects_response: false)

        described_class.call(document: document, current_user: lead, routing_params: params)

        expect(document.reload.response_deadline).to be_nil
      end

      context "when routing_params includes in_reply_to_id" do
        let(:original) { create(:document, :finalized, :expecting_response, entity: entity, department: department) }
        let(:routing_params) do
          { action_user_id: action_user.id, expects_response: false, in_reply_to_id: original.id, info_user_ids: [ "" ] }
        end

        it "persists the link to the original document" do
          described_class.call(document: document, current_user: lead, routing_params: routing_params)

          expect(document.reload.in_reply_to).to eq(original)
        end

        it "clears the original document from its creator's waiting list" do
          creator = original.created_by
          described_class.call(document: document, current_user: lead, routing_params: routing_params)

          expect(Document.waiting_for(creator)).not_to include(original)
        end
      end
    end

    context "when the action user is not a member of the document's department" do
      let(:outsider) { create(:user) }
      let!(:outsider_entity_user) { create(:entity_user, entity: entity, user: outsider, status: "active") }

      it "does not route the document and returns an explicit message" do
        result = described_class.call(
          document: document, current_user: lead,
          routing_params: routing_params.merge(action_user_id: outsider.id)
        )

        expect(result).not_to be_success
        expect(result.message).to include("Action assignee")
        expect(document.reload.routed_at).to be_nil
      end
    end
  end
end
