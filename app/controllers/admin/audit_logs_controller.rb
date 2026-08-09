# frozen_string_literal: true

module Admin
  class AuditLogsController < BaseController
    def index
      @audit_logs = AuditLog.recent.includes(:user).page(params[:page])
    end

    def show
      @audit_log = AuditLog.find(params[:id])
    end
  end
end
