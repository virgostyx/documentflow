# frozen_string_literal: true

class ContactsController < ApplicationController
  include EntityScoped

  before_action :set_contact, only: %i[edit update destroy]

  def index
    @contacts = policy_scope(Contact).where(entity: current_entity).order(:last_name, :first_name)
  end

  def new
    @contact = current_entity.contacts.new
    authorize @contact
  end

  def create
    @contact = current_entity.contacts.new(contact_params)
    authorize @contact

    if @contact.save
      redirect_to entity_contacts_path(current_entity), notice: "Contact created successfully."
    else
      flash.now[:alert] = @contact.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @contact
  end

  def update
    authorize @contact

    if @contact.update(contact_params)
      redirect_to entity_contacts_path(current_entity), notice: "Contact updated successfully."
    else
      flash.now[:alert] = @contact.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
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
