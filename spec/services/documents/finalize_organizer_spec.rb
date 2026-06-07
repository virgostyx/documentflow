# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::FinalizeOrganizer do
  let(:user) { create(:user) }
  let(:document) { create(:document, :signed, created_by: user) }

  describe ".call" do
    context "quand le document est signé" do
      it "passe le document en finalized et le gèle" do
        described_class.call(document: document, current_user: user)

        document.reload
        expect(document).to be_finalized
        expect(document.frozen?).to be true
      end

      it "planifie la conversion PDF" do
        expect(PdfConversionJob).to receive(:perform_later).with(document.id)

        described_class.call(document: document, current_user: user)
      end

      it "notifie le créateur de la finalisation" do
        expect(NotificationJob).to receive(:perform_later).with(user.id, "action_required", document.id)

        described_class.call(document: document, current_user: user)
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(document: document, current_user: user)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "quand le document n'est pas signé" do
      let(:document) { create(:document, :in_progress, created_by: user) }

      it "retourne un échec et ne change pas le statut" do
        result = described_class.call(document: document, current_user: user)

        expect(result).not_to be_success
        expect(document.reload.status).to eq("in_progress")
      end
    end
  end
end
