class ApplicationController < ActionController::Base
     allow_browser versions: :modern

     before_action :check_session_access

     helper_method :current_user, :signed_in?

     private

     # Check every page and action, including public pages, after access is revoked.
     def check_session_access
          return unless session[:user_id]

          require_sign_in unless signed_in?
     end

     def current_user
          @current_user ||= User.find_by(id: session[:user_id], access_revoked_at: nil)
     end

     def signed_in?
          current_user.present?
     end

     def require_sign_in
          return if signed_in?

          if session[:user_id]
               reset_session
               return redirect_to login_path, alert: "Access not authorized. Your access has been removed."
          end
          redirect_to login_path, alert: "Please sign in to view that page."
     end

     def deny_access(message = "You are not authorized to perform that action.")
          redirect_to root_path, alert: message
     end
end
