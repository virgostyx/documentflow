# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def update
      return super unless current_user.passwordless?

      self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
      resource_updated = resource.update_without_password(account_update_params.except(:current_password, :password, :password_confirmation))

      if resource_updated
        set_flash_message_for_update(resource, {})
        bypass_sign_in(resource, scope: resource_name)
        respond_with resource, location: after_update_path_for(resource)
      else
        clean_up_passwords resource
        respond_with resource
      end
    end
  end
end
