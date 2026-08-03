# frozen_string_literal: true

require "net/imap"
require "mail"

# Polls a single shared IMAP mailbox for emails BCC'd (outgoing archive) or
# redirected/forwarded (incoming archive) by DocumentFlow users from Outlook,
# and dispatches each message to the matching pipeline based on which
# configured address received it (Delivered-To/X-Original-To header).
# See EmailArchive::CreateOrganizer (outgoing) and
# EmailArchive::IncomingMailIngestor (incoming).
class PollEmailArchiveMailboxJob < ApplicationJob
  queue_as :default

  def perform
    return unless imap_configured?

    with_imap_connection do |imap|
      imap.search([ "UNSEEN" ]).each { |seq_no| process_message(imap, seq_no) }
    end
  end

  private

  def imap_configured?
    ENV["EMAIL_ARCHIVE_IMAP_HOST"].present? &&
      ENV["EMAIL_ARCHIVE_IMAP_USERNAME"].present? &&
      ENV["EMAIL_ARCHIVE_IMAP_PASSWORD"].present?
  end

  def with_imap_connection
    imap = Net::IMAP.new(ENV["EMAIL_ARCHIVE_IMAP_HOST"], port: ENV.fetch("EMAIL_ARCHIVE_IMAP_PORT", 993).to_i, ssl: true)
    imap.login(ENV["EMAIL_ARCHIVE_IMAP_USERNAME"], ENV["EMAIL_ARCHIVE_IMAP_PASSWORD"])
    imap.select("INBOX")
    yield imap
  ensure
    imap&.logout
    imap&.disconnect
  end

  def process_message(imap, seq_no)
    raw = imap.fetch(seq_no, "RFC822")[0].attr["RFC822"]
    mail = Mail.new(raw)

    dispatch(mail, delivered_to_address(mail))
  rescue StandardError => e
    Rails.logger.error("[PollEmailArchiveMailboxJob] failed to process message ##{seq_no}: #{e.message}")
  ensure
    imap.store(seq_no, "+FLAGS", [ :Seen ])
  end

  # Delivered-To/X-Original-To aren't recognized address-type headers by the
  # mail gem (unlike From/To/Cc), so read their decoded string value directly
  # rather than relying on the structured #addrs accessor.
  def delivered_to_address(mail)
    header = mail[:delivered_to] || mail[:x_original_to] || mail[:envelope_to]
    header&.value&.strip&.downcase
  end

  def dispatch(mail, delivered_to)
    return log_unmatched(delivered_to) if delivered_to.blank?

    if Department.exists?(archive_ingestion_email: delivered_to)
      result = EmailArchive::CreateOrganizer.call(mail: mail, delivered_to: delivered_to)
      Rails.logger.warn("[PollEmailArchiveMailboxJob] outgoing archive failed: #{result.message}") if result.failure?
    elsif Entity.exists?(incoming_archive_email: delivered_to)
      result = EmailArchive::IncomingMailIngestor.call(mail, delivered_to: delivered_to)
      Rails.logger.warn("[PollEmailArchiveMailboxJob] incoming archive failed: #{result.reason}") unless result.success?
    else
      log_unmatched(delivered_to)
    end
  end

  def log_unmatched(delivered_to)
    Rails.logger.warn("[PollEmailArchiveMailboxJob] no department/entity configured for #{delivered_to.inspect}")
  end
end
