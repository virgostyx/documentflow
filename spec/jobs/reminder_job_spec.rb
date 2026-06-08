# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReminderJob do
  describe "#perform" do
    it "reminds the actor of the current pending step on each in-progress document" do
      document = create(:document, :with_workflow, :in_progress)
      step = document.current_step

      expect(NotificationJob).to receive(:perform_later).with(step.actor.id, "action_required", document.id)

      described_class.new.perform
    end

    it "does not send reminders for documents that are not in progress" do
      create(:document, :with_workflow)

      expect(NotificationJob).not_to receive(:perform_later)

      described_class.new.perform
    end

    it "skips steps without an assigned actor" do
      document = create(:document, :with_workflow, :in_progress)
      document.current_step.update!(actor: nil)

      expect(NotificationJob).not_to receive(:perform_later)

      described_class.new.perform
    end
  end
end
