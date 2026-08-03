# frozen_string_literal: true

module EmailArchive
  # Turns a raw email (redirected or forwarded-as-attachment by a
  # DocumentFlow user into an entity's incoming-archive mailbox) into an
  # auto-registered incoming Document, by resolving the relaying user and
  # original sender and then delegating to the existing, unmodified
  # IncomingMails::RegisterOrganizer — the relaying user becomes the Lead,
  # filed under their own primary department, exactly as if they'd filled in
  # the registration form themselves.
  class IncomingMailIngestor
    Result = Struct.new(:success?, :reason, keyword_init: true)

    class << self
      def call(mail, delivered_to:)
        new(mail, delivered_to: delivered_to).call
      end
    end

    def initialize(mail, delivered_to:)
      @mail = mail
      @delivered_to = delivered_to
    end

    def call
      entity = Entity.find_by(incoming_archive_email: @delivered_to)
      return failure("no entity configured for #{@delivered_to}") unless entity

      extracted = ExtractOriginalMessage.call(@mail)
      original = extracted.message

      entity_user = Actions::ResolveRedirectingUser.call(entity: entity, relaying_address: extracted.relaying_address)
      return failure("could not resolve relaying user for #{extracted.relaying_address.inspect}") unless entity_user

      from = original[:from]&.addrs&.first
      return failure("original message has no From address") unless from

      contact = Actions::ResolveOriginalSenderContact.call(entity: entity, from_address: from.address, from_name: from.display_name)
      return failure("could not resolve/create sender contact for #{from.address}") unless contact&.persisted?

      result = IncomingMails::RegisterOrganizer.call(
        entity: entity,
        current_user: entity_user.user,
        document_params: document_params_for(original, entity_user, contact)
      )

      result.success? ? success : failure(result.message)
    end

    private

    def document_params_for(original, entity_user, contact)
      {
        subject: original.subject.presence || "(no subject)",
        document_date: (original.date || Time.current).to_date,
        department_id: entity_user.primary_department.id,
        sender_token: "Contact-#{contact.id}",
        lead_user_id: entity_user.user_id,
        main_file: RenderBodyToPdf.call(original),
        annexes: original.attachments.map { |attachment| uploaded_file_hash(attachment) }
      }
    end

    def uploaded_file_hash(attachment)
      { io: StringIO.new(attachment.body.decoded), filename: attachment.filename, content_type: attachment.mime_type }
    end

    def success
      Result.new(success?: true, reason: nil)
    end

    def failure(reason)
      Result.new(success?: false, reason: reason)
    end
  end
end
