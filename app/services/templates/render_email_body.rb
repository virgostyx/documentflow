# frozen_string_literal: true

module Templates
  # Renders an EmailTemplate's body into a Document#dispatch_message: fills
  # ordinary tags and the reserved {{date}} tag immediately, but leaves the
  # reserved {{recipient_name}} tag literal in the returned text - it's only
  # resolved per-recipient, at actual send time (see NotificationMailer).
  module RenderEmailBody
    Result = Struct.new(:body, :missing_fields, keyword_init: true) do
      def success?
        missing_fields.empty?
      end
    end

    def self.call(email_template:, field_values:)
      field_values = field_values || {}

      missing_fields = email_template.email_template_fields.select do |field|
        field.required? && field_values[field.tag_name].to_s.strip.empty?
      end
      return Result.new(body: nil, missing_fields: missing_fields) if missing_fields.any?

      body = email_template.body_template.gsub(Templates::TagScanner::TAG_PATTERN) do
        case Regexp.last_match(1)
        when "date" then I18n.l(Date.current)
        when "recipient_name" then "{{recipient_name}}"
        else field_values[Regexp.last_match(1)].to_s
        end
      end

      Result.new(body: body, missing_fields: [])
    end
  end
end
