# frozen_string_literal: true

module Admin
  # Read-only browser (no forms, no write path) over the models allowlisted in
  # Admin::ModelRegistry. Deliberately not a generic editor: most mutations in
  # this app flow through a service/organizer layer with invariants (AASM
  # states, workflow step ordering, invitation side effects) that a generic
  # "edit any column" form would bypass.
  class RecordsController < BaseController
    REDACTED_PLACEHOLDER = "•••• (redacted)"

    before_action :set_model_entry

    def index
      @records = @klass.order(:id).page(params[:page])
    end

    def show
      @record = @klass.find(params[:id])
    end

    private

    def set_model_entry
      @model_name = params[:model]
      entry = Admin::ModelRegistry::ENTRIES.fetch(@model_name)
      @klass = entry[:klass]
      @redacted_columns = entry[:redacted_columns] || []
      @columns = @klass.column_names
    end

    def display_value(record, column)
      return REDACTED_PLACEHOLDER if @redacted_columns.include?(column)

      record.public_send(column)
    end
    helper_method :display_value
  end
end
