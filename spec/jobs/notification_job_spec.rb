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

    it "delivers a document_finalized notification" do
      expect(NotificationMailer).to receive(:document_finalized)
        .with(user, document)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "document_finalized", document.id)
    end

    it "delivers a rejection_alert notification with the given reason" do
      expect(NotificationMailer).to receive(:rejection_alert)
        .with(user, document, "Pièce manquante")
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "rejection_alert", document.id, reason: "Pièce manquante")
    end

    it "delivers a mail_lead_assigned notification" do
      expect(NotificationMailer).to receive(:mail_lead_assigned)
        .with(user, document)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "mail_lead_assigned", document.id)
    end

    it "delivers a mail_action_assigned notification" do
      expect(NotificationMailer).to receive(:mail_action_assigned)
        .with(user, document)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "mail_action_assigned", document.id)
    end

    it "delivers a checked_out notification" do
      expect(NotificationMailer).to receive(:checked_out)
        .with(user, document)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "checked_out", document.id)
    end

    it "delivers a checked_in notification" do
      expect(NotificationMailer).to receive(:checked_in)
        .with(user, document)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

      described_class.new.perform(user.id, "checked_in", document.id)
    end
  end
end
