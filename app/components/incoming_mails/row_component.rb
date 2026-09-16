# frozen_string_literal: true

module IncomingMails
  # A single row of the Incoming Mail triage table. Deliberately
  # self-contained (no dependency on an ambient current_entity controller
  # helper) so it can be rendered identically from a real request
  # (incoming_mails/_table) or out-of-request from IncomingMailRowBroadcastJob.
  class RowComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    private

    attr_reader :document

    def row_path
      entity_incoming_mail_path(document.entity, document)
    end
  end
end
