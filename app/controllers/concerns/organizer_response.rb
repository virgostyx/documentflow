# frozen_string_literal: true

# Redirects after an organizer call, based on its result.
module OrganizerResponse
  extend ActiveSupport::Concern

  private

  def redirect_on_result(result, success_path:, failure_path: success_path, success_message: nil, failure_message: result.message)
    if result.success?
      redirect_to success_path, notice: success_message
    else
      redirect_to failure_path, alert: failure_message
    end
  end
end
