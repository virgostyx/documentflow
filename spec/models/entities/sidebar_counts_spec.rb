# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entities::SidebarCounts do
  let(:user) { create(:user) }
  let(:entity) { create(:entity) }
  let!(:entity_user) { create(:entity_user, :owner, entity: entity, user: user) }

  subject(:counts) { described_class.new(current_entity: entity, current_user: user) }

  describe "#overview_count" do
    it "only counts finalized documents" do
      create(:document, :finalized, entity: entity)
      create(:document, entity: entity)

      expect(counts.overview_count).to eq(1)
    end
  end

  describe "#to_validate_count" do
    it "counts documents where the user is the actor of the current pending step" do
      document = create(:document, :with_workflow, :in_progress, entity: entity)
      document.workflow_steps.find_by(role: "RED").update!(status: "approved")
      document.workflow_steps.find_by(role: "VISA").update!(actor: user)

      expect(counts.to_validate_count).to eq(1)
    end

    it "does not count a document when the user's step is not yet current" do
      document = create(:document, :with_workflow, :in_progress, entity: entity)
      document.workflow_steps.find_by(role: "SIGN").update!(actor: user)

      expect(counts.to_validate_count).to eq(0)
    end
  end

  describe "#received_count" do
    it "counts finalized documents addressed to the user" do
      create(:document, :finalized, entity: entity, addressee: user)

      expect(counts.received_count).to eq(1)
    end

    it "excludes a matching document that is not yet finalized" do
      create(:document, entity: entity, addressee: user)

      expect(counts.received_count).to eq(0)
    end
  end

  describe "#mine_count" do
    it "counts non-finalized documents authored by the user" do
      create(:document, entity: entity, created_by: user)

      expect(counts.mine_count).to eq(1)
    end

    it "excludes the user's finalized documents" do
      create(:document, :finalized, entity: entity, created_by: user)

      expect(counts.mine_count).to eq(0)
    end
  end

  describe "#todo_count" do
    it "counts finalized documents addressed to the user expecting a response" do
      create(:document, :finalized, :expecting_response, entity: entity, addressee: user)

      expect(counts.todo_count).to eq(1)
    end

    it "excludes a matching document that is not yet finalized" do
      create(:document, :expecting_response, entity: entity, addressee: user)

      expect(counts.todo_count).to eq(0)
    end
  end

  describe "#waiting_count" do
    it "counts finalized documents authored by the user expecting a response" do
      create(:document, :finalized, :expecting_response, entity: entity, created_by: user)

      expect(counts.waiting_count).to eq(1)
    end

    it "excludes a matching document that is not yet finalized" do
      create(:document, :expecting_response, entity: entity, created_by: user)

      expect(counts.waiting_count).to eq(0)
    end
  end

  describe "#info_count" do
    it "counts finalized documents addressed to the user not expecting a response" do
      create(:document, :finalized, entity: entity, addressee: user)

      expect(counts.info_count).to eq(1)
    end

    it "excludes a matching document that is not yet finalized" do
      create(:document, entity: entity, addressee: user)

      expect(counts.info_count).to eq(0)
    end
  end

  describe "#incoming_mail_count" do
    it "counts incoming mail awaiting the user's triage as lead" do
      create(:document, :incoming, entity: entity, lead_user: user, addressee: user)

      expect(counts.incoming_mail_count).to eq(1)
    end

    it "does not count routed mail" do
      create(:document, :incoming, entity: entity, lead_user: user, addressee: user, routed_at: Time.current)

      expect(counts.incoming_mail_count).to eq(0)
    end
  end

  describe "#documents_base_scope" do
    it "is scoped to outgoing documents visible to the user within the entity" do
      other_entity = create(:entity)
      create(:document, entity: other_entity)
      outgoing = create(:document, entity: entity)
      create(:document, :incoming, entity: entity)

      expect(counts.documents_base_scope).to contain_exactly(outgoing)
    end
  end
end
