Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Public landing page
  root "pages#home"

  devise_for :users, controllers: {
    sessions: "users/sessions",
    passwords: "users/passwords",
    registrations: "users/registrations"
  }

  devise_scope :user do
    resource :two_factor_authentication, only: %i[new create], controller: "users/two_factor_authentications"

    get  "passkey_session/options", to: "users/passkey_sessions#options", as: :passkey_session_options
    post "passkey_session",         to: "users/passkey_sessions#create",  as: :passkey_session

    get  "recovery_code_session/new", to: "users/recovery_code_sessions#new",    as: :new_recovery_code_session
    post "recovery_code_session",     to: "users/recovery_code_sessions#create", as: :recovery_code_session
  end

  resource :two_factor_setup, only: %i[show create destroy], controller: "users/two_factor_setups"
  post "two_factor_setup/backup_codes", to: "users/two_factor_setups#backup_codes", as: :two_factor_setup_backup_codes

  resources :passkeys, only: %i[index create destroy], controller: "users/passkeys" do
    get :options, on: :collection
  end

  resource :signature, only: %i[show create destroy], controller: "users/signatures"

  mount ActionCable.server => "/cable"
  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :admin do
    root to: "dashboard#index"

    resources :users, only: %i[index show] do
      member do
        get   :confirm_revoke_super_admin
        patch :grant_super_admin
        patch :revoke_super_admin
      end
    end
    resources :entities, only: %i[index show]
    resources :audit_logs, only: %i[index show]

    get "records/:model",     to: "records#index", as: :records,
        constraints: { model: Regexp.union(Admin::ModelRegistry::ENTRIES.keys) }
    get "records/:model/:id", to: "records#show",  as: :record,
        constraints: { model: Regexp.union(Admin::ModelRegistry::ENTRIES.keys) }
  end

  # Authenticated application
  resources :entities do
    resources :entity_users, only: %i[index create update destroy] do
      member do
        get :edit_departments
        patch :update_departments
      end
    end
    resources :contacts
    resources :circuit_templates, controller: "entities/circuit_templates"
    resources :document_templates, controller: "entities/document_templates" do
      resource :generation, only: %i[new create], controller: "entities/document_templates/generations"
    end
    resources :email_templates, controller: "entities/email_templates"
    resources :departments, controller: "entities/departments"
    resources :classification_nodes, controller: "entities/classification_nodes" do
      member do
        get :confirm_destroy
      end
    end

    resources :documents do
      resources :workflow_steps, only: %i[create update destroy] do
        member do
          post :approve
          get :confirm_reject
          post :reject
          post :move_up
          post :move_down
          patch :reassign
          get :confirm_sign
          get :confirm_exp
          get :step_up_options
          post :step_up_verify
        end
        collection do
          post :apply_template
          post :reorder
        end
      end
      resources :shared_links, only: %i[create destroy]
      resources :cc_recipients, only: %i[create destroy] do
        collection do
          post :bulk_create
        end
      end
      resource :main_file, only: %i[create destroy] do
        get :preview
        get :preview_content
      end
      resources :annexes, only: %i[create destroy] do
        member do
          get :preview
          get :preview_content
        end
      end
      resource :checkout, only: %i[create update destroy], controller: "document_checkouts" do
        get :confirm_check_in, on: :member
        get :confirm_cancel, on: :member
        get :edit_online, on: :member
      end

      member do
        post :launch
        post :cancel
        get :confirm_cancel
        get :confirm_destroy
        get :classify_form
        patch :classify
      end
      collection do
        get :search
        get :mine
        get :received
        get :todo
        get :waiting
        get :info
        get :to_validate
      end
    end

    resources :incoming_mails, only: %i[index new create show] do
      member do
        get :route_form
        patch :route
      end
    end

    resource :settings, only: %i[show], controller: "entities/settings"
  end

  # Public access to a shared document (no authentication)
  get "share/:token", to: "shared_links#show", as: :shared_document
  post "share/:token/renew", to: "shared_links#renew", as: :renew_shared_document
  get "share/:token/preview", to: "shared_links#preview_main_file", as: :preview_shared_document
  get "share/:token/preview_content", to: "shared_links#preview_main_file_content", as: :preview_content_shared_document
  get "share/:token/annexes/:id/preview", to: "shared_links#preview_annex", as: :preview_shared_document_annex
  get "share/:token/annexes/:id/preview_content", to: "shared_links#preview_annex_content", as: :preview_content_shared_document_annex

  # Public invitation acceptance (token-based, no authentication required)
  get  "/invitations/:token",          to: "invitations#show",           as: :invitation
  get  "/invitations/:token/register", to: "invitations#register",       as: :invitation_register
  post "/invitations/:token/register", to: "invitations#create_account", as: :invitation_create_account

  # WOPI host endpoints for Collabora Online (token-based, called server-to-server, no session auth)
  namespace :wopi do
    get  "files/:id",          to: "files#check_file_info", as: :file
    get  "files/:id/contents", to: "files#get_file",         as: :file_contents
    post "files/:id/contents", to: "files#put_file"
    post "files/:id",          to: "files#lock_dispatch"
  end

  # Global dashboard (list of the user's entities)
  get "dashboard", to: "dashboard#index"
end
