# frozen_string_literal: true

# Redirects after a record save/update, or re-renders the form with its errors.
module SavesAndResponds
  extend ActiveSupport::Concern

  private

  # success_path may be a plain path or a callable, needed when it depends on
  # an attribute (e.g. the record's id) only set once the save/update succeeds.
  def save_and_respond(record, success_path:, success_message:, failure_template:)
    if yield
      redirect_to (success_path.respond_to?(:call) ? success_path.call : success_path), notice: success_message
    else
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render failure_template, status: :unprocessable_content
    end
  end
end
