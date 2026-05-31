Rails.application.routes.draw do
  root "home#index"

  # Auth
  get    "/signup",    to: "users#new",        as: :signup
  post   "/signup",    to: "users#create"
  get    "/login",     to: "sessions#new",     as: :login
  post   "/login",     to: "sessions#create"
  delete "/logout",    to: "sessions#destroy", as: :logout

  # Dashboard
  get "/dashboard",       to: "dashboard#index", as: :dashboard
  get "/dashboard/stats", to: "dashboard#stats", as: :dashboard_stats

  # REST API — versioned under /api/v1/
  namespace :api do
    namespace :v1 do
      resources :urls, only: %i[create show update destroy], param: :key
    end
  end

  # URL shortener (web form)
  resources :short_urls, only: [ :create ]

  get "up" => "rails/health#show", as: :rails_health_check

  # Must be last — catches /:key for short URL redirects.
  get ":key", to: "short_urls#redirect",
              constraints: { key: /[0-9a-zA-Z]{7}/ },
              as: :short_url_redirect
end
