class DashboardController < ApplicationController
  def index
    @entities = policy_scope(Entity).order(:name)
  end
end
