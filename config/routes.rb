Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Public landing page
  root "pages#home"

  devise_for :users

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
        end
        collection do
          post :apply_template
          post :reorder
        end
      end
      resources :shared_links, only: %i[create destroy]
      resources :cc_recipients, only: %i[create destroy]
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
      end

      member do
        post :launch
        post :cancel
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

    resources :incoming_mails, only: %i[new create show] do
      member do
        get :route_form
        patch :route
      end
      collection do
        get :inbox
        get :pending_triage
      end
    end

    resource :settings, only: %i[show], controller: "entities/settings"
  end

  # Public access to a shared document (no authentication)
  get "share/:token", to: "shared_links#show", as: :shared_document

  # Public invitation acceptance (token-based, no authentication required)
  get  "/invitations/:token",          to: "invitations#show",           as: :invitation
  get  "/invitations/:token/register", to: "invitations#register",       as: :invitation_register
  post "/invitations/:token/register", to: "invitations#create_account", as: :invitation_create_account

  # Global dashboard (list of the user's entities)
  get "dashboard", to: "dashboard#index"
end
