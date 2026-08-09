# frozen_string_literal: true

module Admin
  class EntitiesController < BaseController
    def index
      @entities = Entity.order(:name).page(params[:page])
    end

    def show
      @entity = Entity.find(params[:id])
    end
  end
end
