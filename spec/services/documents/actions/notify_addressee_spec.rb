# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Actions::NotifyAddressee do
  let(:document) { create(:document) }

  let(:ctx) { LightService::Context.make(document: document) }

  describe ".execute" do
    it "enqueues an addressee_notification job for the document's addressee" do
      expect(AddresseeNotificationJob).to receive(:perform_later)
        .with(document.addressee_type, document.addressee_id, document.id)

      described_class.execute(ctx)
    end

    it "succeeds" do
      result = described_class.execute(ctx)

      expect(result).to be_success
    end
  end
end
