# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::CheckInOrganizer do
  let(:document) { create(:document, :with_workflow, :in_progress) }
  let(:visa_actor) { document.workflow_steps.find_by(role: "VISA").actor }
  let(:new_file) { fixture_file_upload("sample.pdf", "application/pdf") }
  let(:new_annex_file) { fixture_file_upload("sample.pdf", "application/pdf") }
  let(:annex) { create(:annex, document: document) }

  before { document.update!(checked_out_by: visa_actor, checked_out_at: 1.hour.ago) }

  describe ".call" do
    context "when checked in by the user who checked it out" do
      it "creates a new document file version for the main file" do
        expect {
          described_class.call(document: document, current_user: visa_actor, main_file: new_file, comment: "Fixed typo")
        }.to change(DocumentFileVersion, :count).by(1)

        version = document.document_file_versions.last
        expect(version.user).to eq(visa_actor)
        expect(version.version_number).to eq(1)
        expect(version.comment).to eq("Fixed typo")
        expect(version.annex_id).to be_nil
        expect(version.file).to be_attached
      end

      it "replaces the document's main_file with the new content" do
        described_class.call(document: document, current_user: visa_actor, main_file: new_file, comment: nil)

        expect(document.reload.main_file.filename.to_s).to eq("sample.pdf")
      end

      it "releases the checkout lock" do
        described_class.call(document: document, current_user: visa_actor, main_file: new_file, comment: nil)

        document.reload
        expect(document.checked_out_by).to be_nil
        expect(document.checked_out_at).to be_nil
      end

      it "increments the version number on subsequent check-ins" do
        described_class.call(document: document, current_user: visa_actor, main_file: new_file, comment: nil)
        document.update!(checked_out_by: visa_actor, checked_out_at: Time.current)

        described_class.call(document: document, current_user: visa_actor, main_file: new_file, comment: nil)

        expect(document.document_file_versions.maximum(:version_number)).to eq(2)
      end

      it "logs an audit event" do
        expect {
          described_class.call(document: document, current_user: visa_actor, main_file: new_file, comment: nil)
        }.to change(AuditLog, :count).by(1)

        expect(AuditLog.last.action).to eq("check_in")
      end

      it "notifies the current step actor of the new version" do
        expect(NotificationJob).to receive(:perform_later).with(document.created_by.id, "checked_in", document.id)

        described_class.call(document: document, current_user: visa_actor, main_file: new_file, comment: nil)
      end
    end

    context "when checking in only an annex, with no main file" do
      it "creates a version for the annex and leaves main_file untouched" do
        original_filename = document.main_file.filename.to_s

        result = described_class.call(
          document: document, current_user: visa_actor, annex_files: { annex.id => new_annex_file }, comment: nil
        )

        expect(result).to be_success
        expect(annex.reload.file.filename.to_s).to eq("sample.pdf")
        expect(document.reload.main_file.filename.to_s).to eq(original_filename)
      end
    end

    context "when checking in both the main file and an annex together" do
      it "creates versions sharing the same version_number" do
        described_class.call(
          document: document, current_user: visa_actor,
          main_file: new_file, annex_files: { annex.id => new_annex_file }, comment: "Both updated"
        )

        versions = document.document_file_versions.reload
        expect(versions.map(&:version_number).uniq).to eq([ 1 ])
        expect(versions.map(&:annex_id)).to contain_exactly(nil, annex.id)
      end

      it "replaces both the main_file and the annex content" do
        described_class.call(
          document: document, current_user: visa_actor,
          main_file: new_file, annex_files: { annex.id => new_annex_file }, comment: nil
        )

        expect(document.reload.main_file.filename.to_s).to eq("sample.pdf")
        expect(annex.reload.file.filename.to_s).to eq("sample.pdf")
      end
    end

    context "when neither a main file nor any annex file is given" do
      it "fails and does not release the checkout" do
        result = described_class.call(document: document, current_user: visa_actor, comment: nil)

        expect(result).not_to be_success
        expect(document.reload.checked_out_by).to eq(visa_actor)
      end
    end

    context "when checking in with skip_release (WOPI autosave)" do
      it "keeps the document checked out and does not notify" do
        expect(NotificationJob).not_to receive(:perform_later)

        result = described_class.call(
          document: document, current_user: visa_actor, main_file: new_file, comment: nil, skip_release: true
        )

        expect(result).to be_success
        document.reload
        expect(document.checked_out_by).to eq(visa_actor)
        expect(document.checked_out_at).to be_present
      end
    end

    context "when checked in by someone other than the user who checked it out" do
      let(:other_user) { create(:user) }

      it "fails and does not create a version" do
        expect {
          described_class.call(document: document, current_user: other_user, main_file: new_file, comment: nil)
        }.not_to change(DocumentFileVersion, :count)
      end

      it "does not release the lock" do
        described_class.call(document: document, current_user: other_user, main_file: new_file, comment: nil)

        expect(document.reload.checked_out_by).to eq(visa_actor)
      end
    end
  end
end
