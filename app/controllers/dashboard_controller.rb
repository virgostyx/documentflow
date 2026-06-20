class DashboardController < ApplicationController
  def index
    @entities = policy_scope(Entity).order(:name)
    redirect_to entity_documents_path(@entities.first) if @entities.one?
  end
end
