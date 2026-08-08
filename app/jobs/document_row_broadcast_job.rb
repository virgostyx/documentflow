# frozen_string_literal: true

# Live-inserts a newly finalized document's row at the top of the Overview
# table for every user who'd see it there — entity owners/admins
# (unrestricted) plus active members/guests of the document's own
# department, mirroring DepartmentScoped's visibility rule. Triggered
# whenever an outgoing document becomes finalized, whether through the
# normal RED→VISA→SIGN→EXP circuit (Documents::FinalizeOrganizer) or the
# email-archive pipeline (EmailArchive::CreateOrganizer).
class DocumentRowBroadcastJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  TARGET_DOM_ID = "documents-overview-table-body"

  def perform(document_id)
    document = Document.find(document_id)

    audience_for(document).each { |user| broadcast_row(document, user) }
  end

  private

  def audience_for(document)
    EntityUser.active.where(entity: document.entity).select do |entity_user|
      entity_user.owner? || entity_user.admin? || entity_user.member_of?(document.department)
    end.map(&:user)
  end

  def broadcast_row(document, user)
    row_html = ApplicationController.render(
      Documents::RowComponent.new(document: document, current_user: user),
      layout: false
    )
    stream = Turbo::StreamsChannel.turbo_stream_action_tag(:prepend, target: TARGET_DOM_ID, template: row_html)
    Turbo::StreamsChannel.broadcast_stream_to(document.entity, user, :documents, content: stream)
  end
end
