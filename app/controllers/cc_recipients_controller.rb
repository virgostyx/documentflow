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

  def bulk_create
    authorize CcRecipient.new(document: @document), :create?

    tokens = Array(params[:party_tokens]).reject(&:blank?)
    result = Documents::AddCcRecipientsOrganizer.call(document: @document, cc_party_tokens: tokens)

    if result.success?
      @document.update!(multi_recipient: true) if tokens.any?
      redirect_to entity_document_path(current_entity, @document), notice: "Recipients added to copy successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: result.message
    end
  end

  def add_distribution_list
    authorize CcRecipient.new(document: @document), :create?

    distribution_list = current_user.distribution_lists.find_by(id: params[:distribution_list_id])
    return redirect_to entity_document_path(current_entity, @document), alert: "That distribution list could not be found." if distribution_list.nil?

    result = Documents::AddCcRecipientsFromDistributionListOrganizer.call(document: @document, distribution_list: distribution_list, current_user: current_user)

    if result.success?
      message = result.skipped_count.to_i.zero? ? "Recipients added to copy successfully." : "Recipients added to copy successfully (#{result.skipped_count} member(s) skipped: not part of this entity)."
      redirect_to entity_document_path(current_entity, @document), notice: message
    else
      redirect_to entity_document_path(current_entity, @document), alert: "Could not add the distribution list's recipients."
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
