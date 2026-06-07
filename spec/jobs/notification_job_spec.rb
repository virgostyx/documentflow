# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationJob do
  let(:user) { create(:user) }
  let(:document) { create(:document) }

  describe "#perform" do
    it "delivers an action_required notification" do
      expect(NotificationMailer).to receive(:action_required)
        .with(user, document)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "action_required", document.id)
    end

    it "delivers a rejection_alert notification with the given reason" do
      expect(NotificationMailer).to receive(:rejection_alert)
        .with(user, document, "Pièce manquante")
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "rejection_alert", document.id, reason: "Pièce manquante")
    end
  end
end
