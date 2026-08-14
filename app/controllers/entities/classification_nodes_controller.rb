# frozen_string_literal: true

module Entities
  class ClassificationNodesController < ApplicationController
    include EntityScoped

    before_action :set_classification_node, only: %i[edit update confirm_destroy destroy]

    def index
      @roots = ClassificationNode.sort_by_code(current_entity.classification_nodes.where(parent_id: nil).includes(children: { children: :children }))
    end

    def new
      @classification_node = current_entity.classification_nodes.new(parent_id: params[:parent_id])
      authorize @classification_node
    end

    def create
      @classification_node = current_entity.classification_nodes.new(classification_node_params)
      authorize @classification_node

      if @classification_node.save
        redirect_to entity_classification_nodes_path(current_entity), notice: "Filing node created successfully."
      else
        flash.now[:alert] = @classification_node.errors.full_messages.to_sentence
        render_modal_errors :new
      end
    end

    def edit
      authorize @classification_node
    end

    def update
      authorize @classification_node

      if @classification_node.update(classification_node_params)
        redirect_to entity_classification_nodes_path(current_entity), notice: "Filing node updated successfully."
      else
        flash.now[:alert] = @classification_node.errors.full_messages.to_sentence
        render_modal_errors :edit
      end
    end

    def confirm_destroy
      authorize @classification_node, :destroy?
    end

    def destroy
      authorize @classification_node

      if @classification_node.destroy
        redirect_to entity_classification_nodes_path(current_entity), notice: "Filing node deleted successfully."
      else
        redirect_to entity_classification_nodes_path(current_entity), alert: @classification_node.errors.full_messages.to_sentence
      end
    end

    private

    def set_classification_node
      @classification_node = current_entity.classification_nodes.find(params[:id])
    end

    def classification_node_params
      params.require(:classification_node).permit(:code, :name, :parent_id)
    end

    # The form targets turbo_frame "_top" so a successful save can break out of the
    # modal and land on the index page. On validation failure that same targeting
    # would blow away the modal instead of just showing the errors inside it, so we
    # respond with a turbo stream that replaces the "modal" frame directly.
    def render_modal_errors(template)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("modal", template: "entities/classification_nodes/#{template}"),
                 status: :unprocessable_content
        end
        format.html { render template, status: :unprocessable_content }
      end
    end
  end
end
