# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @user_count = User.count
      @super_admin_count = User.where(super_admin: true).count
      @entity_count = Entity.count
      @document_count = Document.count
      @record_model_names = Admin::ModelRegistry::ENTRIES.keys
    end
  end
end
