# frozen_string_literal: true

module Documents
  # Wraps Actions::CreateCcRecipients in its own organizer purely to get the
  # transaction + all-or-nothing rollback that ApplicationService.call
  # provides (a bulk "add several recipients at once" request shouldn't
  # leave a partial set of cc_recipients behind if one token is invalid).
  class AddCcRecipientsOrganizer < ApplicationService
    workflow_steps Actions::CreateCcRecipients, audit_log: false
  end
end
