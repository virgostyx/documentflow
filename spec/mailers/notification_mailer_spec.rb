# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationMailer do
  let(:user) { create(:user) }
  let(:document) { create(:document) }

  describe "#action_required" do
    let(:mail) { described_class.action_required(user, document) }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "mentions the document in the body" do
      expect(mail.body.encoded).to include(document.reference_number)
    end
  end

  describe "#rejection_alert" do
    let(:mail) { described_class.rejection_alert(user, document, "Pièce manquante") }

    it "is addressed to the user with a subject mentioning the reference number" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(document.reference_number)
    end

    it "includes the rejection reason in the body" do
      expect(mail.body.encoded).to include("Pièce manquante")
    end
  end
end
