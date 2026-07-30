# frozen_string_literal: true

# Builds the iframe src that embeds Collabora Online's editor for a document,
# combining Collabora's own discovery template with the WOPI file URL
# (Wopi::FilesController) and a fresh, per-user access token.
module Wopi
  class EditUrl
    def self.for(document:, user:)
      new(document: document, user: user).build
    end

    def initialize(document:, user:)
      @document = document
      @user = user
    end

    def build
      return nil unless @document.main_file.attached?

      template = Wopi::Discovery.edit_url_template(content_type: @document.main_file.content_type)
      return nil if template.nil?

      base = template.split("?").first
      token = Wopi::AccessToken.encode(document: @document, user: @user)

      "#{base}?WOPISrc=#{CGI.escape(wopi_src_url)}&access_token=#{CGI.escape(token)}"
    end

    private

    def wopi_src_url
      Rails.application.routes.url_helpers.wopi_file_url(@document, **default_url_options)
    end

    def default_url_options
      mailer_options = Rails.application.config.action_mailer.default_url_options || {}
      { protocol: Rails.env.production? ? "https" : "http" }.merge(mailer_options)
    end
  end
end
