# frozen_string_literal: true

module Documents
  class MainFileComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @current_user = current_user
      @policy = Pundit.policy!(current_user, document)
    end

    def attached?
      document.main_file.attached?
    end

    def show_actions?
      @policy.update? && !checked_out_by_other?
    end

    def checked_out?
      document.checked_out?
    end

    def checked_out_by_other?
      document.locked_for?(current_user)
    end

    def show_check_out_button?
      attached? && @policy.check_out?
    end

    def main_file_download_url
      Rails.application.routes.url_helpers.rails_blob_path(document.main_file, disposition: "attachment", only_path: true)
    end

    def show_check_in_button?
      @policy.check_in?
    end

    def show_cancel_check_out_button?
      @policy.cancel_check_out?
    end

    private

    attr_reader :document, :current_user
  end
end
