# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def action_required(user, document)
    @user = user
    @document = document
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Action required: #{document.display_number}")
  end

  def rejection_alert(user, document, reason)
    @user = user
    @document = document
    @reason = reason
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Document rejected: #{document.display_number}")
  end

  def mail_lead_assigned(user, document)
    @user = user
    @document = document
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Incoming mail assigned to you: #{document.display_number}")
  end

  def mail_action_assigned(user, document)
    @user = user
    @document = document
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Action required on incoming mail: #{document.display_number}")
  end

  def checked_out(user, document)
    @user = user
    @document = document
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Document checked out: #{document.display_number}")
  end

  def checked_in(user, document)
    @user = user
    @document = document
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "New document version checked in: #{document.display_number}")
  end

  def document_finalized(user, document)
    @user = user
    @document = document
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Document finalized: #{document.reference_number}")
  end

  def document_addressed(party, document)
    @recipient_name = party.display_name
    @document = document
    @dispatch_message = document.dispatch_message

    if party.external? && document.addressee_dispatch_as_attachment?
      attach_document_files(document)
    elsif party.external?
      @shared_link = document.active_shared_link
      @document_url = shared_document_url(@shared_link.token)
    else
      @document_url = entity_document_url(document.entity, document)
    end

    mail(to: party.email, subject: "Document addressed to you: #{document.reference_number}")
  end

  def cc_notification(party, document)
    @recipient_name = party.display_name
    @document = document
    @dispatch_message = document.dispatch_message
    cc_recipient = document.cc_recipients.find_by(party_type: party.class.name, party_id: party.id)

    if party.external? && cc_recipient&.dispatch_as_attachment?
      attach_document_files(document)
    elsif party.external?
      @shared_link = document.active_shared_link
      @document_url = shared_document_url(@shared_link.token)
    else
      @document_url = entity_document_url(document.entity, document)
    end

    mail(to: party.email, subject: "Document finalized: #{document.reference_number}")
  end

  private

  def attach_document_files(document)
    used_names = Set.new
    [ document.main_file, *document.annexes.map(&:file) ].each do |attached_file|
      next unless attached_file.attached?

      bytes = FilePreviewRenderer.pdf_bytes_for(attached_file)
      filename = unique_filename("#{File.basename(attached_file.filename.to_s, ".*")}.pdf", used_names)
      attachments[filename] = { mime_type: "application/pdf", content: bytes }
    end
    @files_attached = true
  end

  def unique_filename(filename, used_names)
    return filename if used_names.add?(filename)

    ext = File.extname(filename)
    base = File.basename(filename, ext)
    n = 2
    n += 1 until used_names.add?("#{base} (#{n})#{ext}")
    "#{base} (#{n})#{ext}"
  end
end
