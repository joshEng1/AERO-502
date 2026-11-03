Rails.application.routes.draw do
     root "tasks#index"

     # The leader dashboard was merged into the task board (KAN-29); old links go to its hours.
     board_hours = redirect { |_params, request| "#{[ "/tasks", request.query_string.presence ].compact.join("?")}#hours" }
     get "progress", to: board_hours
     resource :timeline, only: :show
     get "dashboard", to: board_hours

     get "login", to: "sessions#new"
     post "login", to: "sessions#create"
     delete "logout", to: "sessions#destroy"
     get "auth/:provider/callback", to: "sessions#omniauth", as: :omniauth_callback
     get "auth/failure", to: "sessions#failure"
     get "help", to: "help#show"
     get "help/restart", to: "help#restart", as: :restart_guide

     resources :users, only: %i[index new create edit update] do
          member do
               patch :revoke
               patch :restore
          end
     end

     get "organization", to: "organization#show"
     concern :archivable do
          member do
               patch :archive
               patch :restore
          end
     end
     resources :teams, :subteams, :projects, only: %i[show new create edit update], concerns: :archivable

     get "reports/member_hours", to: "reports#member_hours", as: :member_hours_report
     get "reports/project_hours", to: "reports#project_hours", as: :project_hours_report
     resources :subteams, only: [] do
          resource :roster, only: %i[update destroy], controller: "rosters"
     end

     resources :tasks do
          resources :time_entries, only: %i[create edit update destroy], shallow: true
     end

     get "up" => "rails/health#show", as: :rails_health_check
end
