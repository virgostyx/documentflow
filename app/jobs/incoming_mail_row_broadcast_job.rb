# frozen_string_literal: true

# Live-inserts a newly registered incoming mail's row at the top of the
# Incoming Mail triage table, for its lead_user only (the sole audience of
# that page — see Document.pending_triage_for). Triggered whenever an
# incoming document is registered, whether through the manual form
# (IncomingMailsController#create) or the email-archive pipeline
# (EmailArchive::IncomingMailIngestor) — both go through
# IncomingMails::RegisterOrganizer.
class IncomingMailRowBroadcastJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  TARGET_DOM_ID = "incoming-mails-table-body"

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.lead_user

    row_html = ApplicationController.render(
      IncomingMails::RowComponent.new(document: document),
      layout: false
    )
    stream = Turbo::StreamsChannel.turbo_stream_action_tag(:prepend, target: TARGET_DOM_ID, template: row_html)
    Turbo::StreamsChannel.broadcast_stream_to(document.entity, document.lead_user, :documents, content: stream)
  end
end
