# frozen_string_literal: true

# Releases WOPI-held checkouts that outlived their access token: if Collabora
# never sends UNLOCK (browser crash, dropped connection), no REFRESH_LOCK can
# land past the token's lifetime either (Wopi::FilesController#authenticate_wopi_request!
# would reject it), so the lock can never legitimately be renewed past that point.
# Manual (non-WOPI) checkouts have no wopi_lock_id and are left untouched — they
# are not time-limited.
class CleanupStaleWopiCheckoutsJob < ApplicationJob
  queue_as :default

  def perform
    Document.where.not(wopi_lock_id: nil)
            .where("checked_out_at < ?", Wopi::AccessToken::DEFAULT_TTL.ago)
            .update_all(checked_out_by_id: nil, checked_out_at: nil, wopi_lock_id: nil)
  end
end
