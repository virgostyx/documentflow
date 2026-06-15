# frozen_string_literal: true

class CcRecipientsController < ApplicationController
  include EntityScoped

  before_action :set_document

  def create
    @cc_recipient = @document.cc_recipients.new(cc_recipient_params)
    authorize @cc_recipient

    if @cc_recipient.save
      redirect_to entity_document_path(current_entity, @document), notice: "Recipient added to copy successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: @cc_recipient.errors.full_messages.to_sentence
    end
  end

  def destroy
    @cc_recipient = @document.cc_recipients.find(params[:id])
    authorize @cc_recipient

    @cc_recipient.destroy
    redirect_to entity_document_path(current_entity, @document), notice: "Recipient removed from copy successfully."
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end

  def cc_recipient_params
    params.require(:cc_recipient).permit(:party_token)
  end
end
