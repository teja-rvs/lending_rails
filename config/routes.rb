Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :borrowers, only: %i[index new create show], constraints: {
    id: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
  } do
    resources :loan_applications, only: :create
  end
  resources :loan_applications, only: %i[index show update], constraints: {
    id: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
  } do
    member do
      patch :approve
      patch :reject
      patch :cancel
    end

    resources :review_steps, only: [] do
      patch :approve, on: :member
      patch :request_details, on: :member
    end
  end
  resources :loans, only: %i[index show update], constraints: {
    id: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
  } do
    member do
      patch :begin_documentation
    end
  end
  mount MissionControl::Jobs::Engine, at: "/jobs"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#index"
end
