# frozen_string_literal: true

module Admin
  class AuditLogRowComponent < ViewComponent::Base
    def initialize(audit_log:)
      @audit_log = audit_log
    end

    private

    attr_reader :audit_log
  end
end
