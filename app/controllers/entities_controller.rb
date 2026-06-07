# frozen_string_literal: true

class EntitiesController < ApplicationController
  before_action :set_entity, only: %i[show edit update destroy]

  def index
    @entities = policy_scope(Entity).order(:name)
  end

  def show
    authorize @entity
  end

  def new
    @entity = Entity.new
    authorize @entity
  end

  def create
    authorize Entity

    result = Entities::CreateOrganizer.call(current_user: current_user, entity_params: entity_params)

    if result.success?
      redirect_to entity_path(result.entity), notice: "Entity created successfully."
    else
      @entity = Entity.new(entity_params)
      flash.now[:alert] = result.message
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @entity
  end

  def update
    authorize @entity

    if @entity.update(entity_params)
      redirect_to entity_path(@entity), notice: "Entity updated successfully."
    else
      flash.now[:alert] = @entity.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @entity
    @entity.destroy
    redirect_to dashboard_path, notice: "Entity deleted successfully."
  end

  private

  def set_entity
    @entity = Entity.find(params[:id])
  end

  def entity_params
    params.require(:entity).permit(:name)
  end
end
