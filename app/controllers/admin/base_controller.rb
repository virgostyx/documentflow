# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include SuperAdminAuthorization

    layout "admin"
  end
end
