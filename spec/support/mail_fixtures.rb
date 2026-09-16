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
  def build_forwarded_mail(forwarded_by:, original:, delivered_to: nil, attachment_content_type: "message/rfc822")
    Mail.new do
      from     forwarded_by
      to       original.to
      subject  "Fwd: #{original.subject}"
      date     Time.current
      text_part { body "See attached." }
      add_file filename: "original.eml", content: original.to_s
    end.tap do |mail|
      mail.attachments.last.content_type = attachment_content_type
      mail["Delivered-To"] = delivered_to if delivered_to
    end
  end

  # A single-part (non-multipart) text/html message: Outlook sends these for
  # HTML-only emails with no alternative text part, unlike the
  # multipart/alternative shape build_archive_mail's DSL always produces —
  # so message.html_part is nil and the raw body must be read via
  # message.decoded (charset-safe) instead of message.body.decoded (raw).
  def build_single_part_html_mail(from:, to:, subject: "Test subject", html_body: "<p>Hello</p>", resent_from: nil)
    raw = +"From: #{from}\r\n"
    raw << "To: #{to}\r\n"
    raw << "Resent-From: #{resent_from}\r\n" if resent_from
    raw << "Subject: #{subject}\r\n"
    raw << "Date: #{Time.current.rfc2822}\r\n"
    raw << "Content-Type: text/html; charset=UTF-8\r\n"
    raw << "Content-Transfer-Encoding: 8bit\r\n"
    raw << "\r\n"
    raw << html_body

    Mail.new(raw.dup.force_encoding("ASCII-8BIT"))
  end

  # A single-part (non-multipart) text/plain message with the same raw,
  # untranscoded-body hazard as build_single_part_html_mail.
  def build_single_part_text_mail(from:, to:, subject: "Test subject", text_body: "Hello")
    raw = +"From: #{from}\r\n"
    raw << "To: #{to}\r\n"
    raw << "Subject: #{subject}\r\n"
    raw << "Date: #{Time.current.rfc2822}\r\n"
    raw << "Content-Type: text/plain; charset=UTF-8\r\n"
    raw << "Content-Transfer-Encoding: 8bit\r\n"
    raw << "\r\n"
    raw << text_body

    Mail.new(raw.dup.force_encoding("ASCII-8BIT"))
  end
end

RSpec.configure do |config|
  config.include MailFixtures
end
