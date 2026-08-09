# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    def index
      @users = User.order(:last_name, :first_name).page(params[:page])
    end

    def show
      @user = User.find(params[:id])
    end

    def confirm_revoke_super_admin
      @user = User.find(params[:id])
    end

    def grant_super_admin
      user = User.find(params[:id])
      user.update!(super_admin: true)

      redirect_to admin_user_path(user), notice: "Granted super admin access to #{user.email}."
    end

    def revoke_super_admin
      user = User.find(params[:id])
      user.update!(super_admin: false)

      redirect_to admin_user_path(user), notice: "Revoked super admin access from #{user.email}."
    end
  end
end
