# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupStaleWopiCheckoutsJob do
  let(:entity) { create(:entity) }
  let(:user) { create(:user) }
  let(:document) { create(:document, :in_progress, entity: entity) }

  describe "#perform" do
    context "when a WOPI checkout has been idle past the access token's lifetime" do
      before do
        document.update!(
          checked_out_by: user,
          checked_out_at: Wopi::AccessToken::DEFAULT_TTL.ago - 1.minute,
          wopi_lock_id: "stale-lock"
        )
      end

      it "releases the checkout" do
        described_class.perform_now

        document.reload
        expect(document.checked_out_by_id).to be_nil
        expect(document.checked_out_at).to be_nil
        expect(document.wopi_lock_id).to be_nil
      end
    end

    context "when a WOPI checkout is still within the access token's lifetime" do
      before do
        document.update!(
          checked_out_by: user,
          checked_out_at: Wopi::AccessToken::DEFAULT_TTL.ago + 5.minutes,
          wopi_lock_id: "fresh-lock"
        )
      end

      it "leaves the checkout untouched" do
        described_class.perform_now

        document.reload
        expect(document.checked_out_by_id).to eq(user.id)
        expect(document.wopi_lock_id).to eq("fresh-lock")
      end
    end

    context "when a document was checked out manually, not via WOPI" do
      before do
        document.update!(
          checked_out_by: user,
          checked_out_at: Wopi::AccessToken::DEFAULT_TTL.ago - 1.day,
          wopi_lock_id: nil
        )
      end

      it "does not release it, since manual checkouts are not time-limited" do
        described_class.perform_now

        document.reload
        expect(document.checked_out_by_id).to eq(user.id)
      end
    end

    context "when a document is not checked out at all" do
      it "does nothing" do
        expect { described_class.perform_now }.not_to change { document.reload.attributes }
      end
    end
  end
end
