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

      it "notifie le créateur de la finalisation" do
        expect(NotificationJob).to receive(:perform_later).with(user.id, "document_finalized", document.id)

        described_class.call(document: document, current_user: user)
      end

      it "diffuse la mise à jour de la sidebar au créateur" do
        expect(SidebarBroadcastJob).to receive(:perform_later).with(user.id, document.entity_id)

        described_class.call(document: document, current_user: user)
      end

      it "notifie le destinataire principal du document" do
        expect(AddresseeNotificationJob).to receive(:perform_later)
          .with(document.addressee_type, document.addressee_id, document.id)

        described_class.call(document: document, current_user: user)
      end

      it "ne diffuse pas la mise à jour de la sidebar quand le destinataire est un Contact" do
        expect(document.addressee_type).to eq("Contact")
        calls = []
        allow(SidebarBroadcastJob).to receive(:perform_later) { |*args| calls << args }

        described_class.call(document: document, current_user: user)

        expect(calls).not_to include([ document.addressee_id, document.entity_id ])
      end

      context "when the addressee is a User" do
        let(:addressee) { create(:user) }
        let(:document) { create(:document, :signed, entity: document_entity, created_by: user, addressee: addressee) }
        let(:document_entity) { create(:entity) }

        before { create(:entity_user, entity: document_entity, user: addressee, status: "active") }

        it "diffuse la mise à jour de la sidebar au destinataire" do
          allow(SidebarBroadcastJob).to receive(:perform_later)

          described_class.call(document: document, current_user: user)

          expect(SidebarBroadcastJob).to have_received(:perform_later).with(addressee.id, document.entity_id)
        end
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(document: document, current_user: user)
        }.to change(AuditLog, :count).by(1)
      end

      context "when the document has cc recipients" do
        let(:contact) { create(:contact, entity: document.entity) }

        before do
          create(:cc_recipient, document: document, party: contact)
        end

        it "notifies each cc recipient" do
          expect(CcNotificationJob).to receive(:perform_later).with("Contact", contact.id, document.id)

          described_class.call(document: document, current_user: user)
        end

        it "ne diffuse pas la mise à jour de la sidebar au contact en copie" do
          calls = []
          allow(SidebarBroadcastJob).to receive(:perform_later) { |*args| calls << args }

          described_class.call(document: document, current_user: user)

          expect(calls).not_to include([ contact.id, document.entity_id ])
        end

        context "and a cc recipient is a User" do
          let(:cc_user) { create(:user) }

          before do
            create(:entity_user, entity: document.entity, user: cc_user, status: "active")
            create(:cc_recipient, document: document, party: cc_user)
          end

          it "diffuse la mise à jour de la sidebar au cc User" do
            allow(SidebarBroadcastJob).to receive(:perform_later)

            described_class.call(document: document, current_user: user)

            expect(SidebarBroadcastJob).to have_received(:perform_later).with(cc_user.id, document.entity_id)
          end
        end
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
