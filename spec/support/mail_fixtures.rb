# frozen_string_literal: true

# Builds in-memory Mail::Message fixtures for EmailArchive specs — no real
# IMAP connection or network activity involved anywhere.
module MailFixtures
  # A plain BCC'd/redirected message: the top-level message IS the original.
  def build_archive_mail(from:, to:, cc: [], subject: "Test subject", body: "<p>Hello</p>", delivered_to: nil, resent_from: nil)
    Mail.new do
      from     from
      to       to
      cc       cc if cc.present?
      subject  subject
      date     Time.current
      html_part { content_type "text/html; charset=UTF-8"; body body }
    end.tap do |mail|
      mail["Delivered-To"] = delivered_to if delivered_to
      mail["Resent-From"] = resent_from if resent_from
    end
  end

  # Outlook "Forward as attachment": the original message is nested as a
  # message/rfc822 attachment inside an outer message from the forwarder.
  def build_forwarded_mail(forwarded_by:, original:, delivered_to: nil)
    Mail.new do
      from     forwarded_by
      to       original.to
      subject  "Fwd: #{original.subject}"
      date     Time.current
      text_part { body "See attached." }
      add_file filename: "original.eml", content: original.to_s
    end.tap do |mail|
      mail.attachments.last.content_type = "message/rfc822"
      mail["Delivered-To"] = delivered_to if delivered_to
    end
  end
end

RSpec.configure do |config|
  config.include MailFixtures
end
