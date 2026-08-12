# frozen_string_literal: true

module Users
  # Self-service management of a user's personal, reusable distribution
  # lists (see DistributionList). Not entity-scoped: ownership through
  # current_user.distribution_lists is the only access control needed here.
  # Routes are nested under an entity, and EntityScoped's current_entity is
  # used only to render the entity app-shell (sidebar/header) the user
  # arrived from -- it does not filter which lists are visible.
  class DistributionListsController < ApplicationController
    include SavesAndResponds
    include EntityScoped

    before_action :set_distribution_list, only: %i[edit update destroy]

    def index
      @distribution_lists = current_user.distribution_lists.order(:name)
    end

    def new
      @distribution_list = current_user.distribution_lists.new
    end

    def create
      @distribution_list = current_user.distribution_lists.new(distribution_list_params)

      save_and_respond(@distribution_list,
                        success_path: entity_distribution_lists_path(current_entity),
                        success_message: "Distribution list created successfully.",
                        failure_template: :new) { @distribution_list.save }
    end

    def edit
    end

    def update
      save_and_respond(@distribution_list,
                        success_path: entity_distribution_lists_path(current_entity),
                        success_message: "Distribution list updated successfully.",
                        failure_template: :edit) { @distribution_list.update(distribution_list_params) }
    end

    def destroy
      @distribution_list.destroy
      redirect_to entity_distribution_lists_path(current_entity), notice: "Distribution list deleted successfully."
    end

    private

    def set_distribution_list
      @distribution_list = current_user.distribution_lists.find(params[:id])
    end

    def distribution_list_params
      params.require(:distribution_list).permit(
        :name,
        distribution_list_members_attributes: %i[id party_token position dispatch_as_attachment _destroy]
      )
    end
  end
end
