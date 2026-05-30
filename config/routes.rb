Rails.application.routes.draw do
  root "home#index"

  resources :short_urls, only: [ :create ]

  get "up" => "rails/health#show", as: :rails_health_check

  # Must be last — catches /:key for short URL redirects.
  # Constraint ensures it only matches 7-char alphanumeric keys so it
  # doesn't shadow other named routes (e.g. /up).
  get ":key", to: "short_urls#redirect",
              constraints: { key: /[0-9a-zA-Z]{7}/ },
              as: :short_url_redirect
end
