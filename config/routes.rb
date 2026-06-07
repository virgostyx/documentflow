Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Public landing page
  root "pages#home"

  devise_for :users

  # Authenticated application
  resources :entities do
    resources :entity_users, only: %i[index create update destroy]
    resources :contacts

    resources :documents do
      resources :workflow_steps, only: [] do
        member do
          post :approve
          post :reject
        end
      end
      resources :shared_links, only: %i[create destroy]

      member do
        post :launch
        post :cancel
      end
      collection do
        get :search
      end
    end
  end

  # Public access to a shared document (no authentication)
  get "share/:token", to: "shared_links#show", as: :shared_document

  # Global dashboard (list of the user's entities)
  get "dashboard", to: "dashboard#index"
end
