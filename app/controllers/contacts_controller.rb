# frozen_string_literal: true

class ContactsController < ApplicationController
  include EntityScoped
  include SavesAndResponds

  before_action :set_contact, only: %i[edit update destroy]

  def index
    authorize Contact.new(entity: current_entity)
    @contacts = policy_scope(Contact).where(entity: current_entity).order(:last_name, :first_name)
  end

  def new
    @contact = current_entity.contacts.new
    authorize @contact
  end

  def create
    @contact = current_entity.contacts.new(contact_params)
    authorize @contact

    if params[:picker_id].present?
      @contact.save
      respond_to do |format|
        format.turbo_stream { render status: @contact.persisted? ? :ok : :unprocessable_content }
      end
    else
      save_and_respond(@contact,
                        success_path: entity_contacts_path(current_entity),
                        success_message: "Contact created successfully.",
                        failure_template: :new) { @contact.save }
    end
  end

  def edit
    authorize @contact
  end

  def update
    authorize @contact

    save_and_respond(@contact,
                      success_path: entity_contacts_path(current_entity),
                      success_message: "Contact updated successfully.",
                      failure_template: :edit) { @contact.update(contact_params) }
  end

  def destroy
    authorize @contact
    @contact.destroy
    redirect_to entity_contacts_path(current_entity), notice: "Contact deleted successfully."
  end

  private

  def set_contact
    @contact = current_entity.contacts.find(params[:id])
  end

  def contact_params
    params.require(:contact).permit(:first_name, :last_name, :email, :company, :phone)
  end
end
