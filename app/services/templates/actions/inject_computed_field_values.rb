# frozen_string_literal: true

module Templates
  module Actions
    class InjectComputedFieldValues < ApplicationAction
      expects :field_values, :document_params
      promises :field_values

      executed do |ctx|
        document_date = begin
          Date.parse(ctx.document_params[:document_date].to_s)
        rescue ArgumentError, TypeError
          nil
        end

        ctx.field_values = (ctx.field_values || {}).merge("date" => document_date ? I18n.l(document_date) : "")
      end
    end
  end
end
