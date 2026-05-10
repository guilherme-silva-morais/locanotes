Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post   :register, to: "registrations#create"
        post   :login,    to: "sessions#create"
        post   :refresh,  to: "sessions#refresh"
        delete :logout,   to: "sessions#destroy"
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no
  # exceptions, otherwise 500. Used by load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
