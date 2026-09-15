# frozen_string_literal: true

module EmailArchive
  # Given a raw ingested Mail::Message, resolves the "true" original message
  # and the address of whoever relayed it into the archive mailbox, handling
  # both Outlook/Exchange delivery styles uniformly:
  #
  # - "Forward as attachment": the original is a nested message/rfc822
  #   attachment; the relaying address is the outer message's From:.
  # - "Redirect": the top-level message *is* the original, unmodified; the
  #   relaying address comes from the Resent-From (fallback Resent-Sender)
  #   header, which Exchange's Redirect action populates per RFC 5322.
  class ExtractOriginalMessage
    Result = Struct.new(:message, :relaying_address, keyword_init: true)

    class << self
      def call(mail)
        forwarded = mail.attachments.find { |attachment| forwarded_message_attachment?(attachment) }

        if forwarded
          Result.new(message: Mail.new(forwarded.body.decoded), relaying_address: Array(mail.from).first)
        else
          Result.new(message: mail, relaying_address: resent_from(mail))
        end
      end

      private

      # Some mail clients (e.g. Outlook's "Forward as Attachment") label the
      # nested .eml as application/octet-stream instead of message/rfc822,
      # so fall back to the filename when the mime type doesn't say so.
      def forwarded_message_attachment?(attachment)
        attachment.mime_type == "message/rfc822" || attachment.filename.to_s.downcase.end_with?(".eml")
      end

      def resent_from(mail)
        Array(mail.resent_from).first || Array(mail.resent_sender).first
      end
    end
  end
end
