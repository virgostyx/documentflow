# frozen_string_literal: true

class DocumentCheckoutsController < ApplicationController
  include EntityScoped

  before_action :set_document

  def confirm_check_in
    authorize @document, :check_in?
  end

  def confirm_cancel
    authorize @document, :cancel_check_out?
  end

  def edit_online
    authorize @document, :check_in?

    @edit_url = build_edit_url
  end

  def create
    authorize @document, :check_out?

    result = Documents::CheckOutOrganizer.call(document: @document, current_user: current_user)

    redirect_to document_path, notice: result.success? ? "Document checked out successfully." : nil,
                                alert: result.success? ? nil : result.message
  end

  def update
    authorize @document, :check_in?

    result = Documents::CheckInOrganizer.call(
      document: @document,
      current_user: current_user,
      main_file: params.dig(:document_file_version, :file),
      annex_files: annex_files_param,
      comment: params.dig(:document_file_version, :comment)
    )

    redirect_to document_path, notice: result.success? ? "Document checked in successfully." : nil,
                                alert: result.success? ? nil : result.message
  end

  def destroy
    authorize @document, :cancel_check_out?

    result = Documents::CancelCheckOutOrganizer.call(document: @document, current_user: current_user)

    redirect_to document_path, notice: result.success? ? "Checkout released successfully." : nil,
                                alert: result.success? ? nil : result.message
  end

  private

  # Collabora may not be configured/reachable yet (e.g. Phase 0 infra not
  # deployed) — that must degrade to the "unavailable" state in the view,
  # not a 500, since the manual check-in flow is still fully usable.
  def build_edit_url
    Wopi::EditUrl.for(document: @document, user: current_user)
  rescue StandardError => e
    Rails.logger.error("[Wopi::EditUrl] #{e.class}: #{e.message}")
    nil
  end

  def annex_files_param
    @document.annexes.each_with_object({}) do |annex, files|
      file = params.dig(:annex_versions, annex.id.to_s)
      files[annex.id] = file if file.present?
    end
  end

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end

  def document_path
    @document.outgoing? ? entity_document_path(current_entity, @document) : entity_incoming_mail_path(current_entity, @document)
  end
end
