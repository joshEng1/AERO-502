class SessionsController < ApplicationController
     NOT_AUTHORIZED = "Access not authorized. Email or password is incorrect, " \
                      "or the account has not been approved yet.".freeze

     def new
          redirect_to root_path if signed_in?
     end

     def create
          unless Rails.configuration.x.password_sign_in
               flash.now[:alert] = "Password sign-in is turned off. Use Sign in with Google."
               return render :new, status: :unprocessable_entity
          end

          user = allowed_user(params[:email])
          if user&.authenticate_password_sign_in(params[:password])
               start_session(user)
          else
               flash.now[:alert] = NOT_AUTHORIZED
               render :new, status: :unprocessable_entity
          end
     end

     # Google sign-in: only verified emails on the allowed-users list get in.
     def omniauth
          auth = request.env["omniauth.auth"]
          verified = auth.dig("extra", "raw_info", "email_verified")
          user = allowed_user(auth.dig("info", "email")) if verified == true

          if user
               start_session(user)
          else
               reset_session
               redirect_to login_path, alert: "Access not authorized. Ask the Chief Engineer to add your email " \
                                              "to the allowed people list."
          end
     end

     def failure
          reset_session
          redirect_to login_path, alert: "Google sign-in was cancelled or failed. Please try again."
     end

     def destroy
          reset_session
          redirect_to login_path, notice: "You have signed out."
     end

     private

     def allowed_user(email)
          User.find_by(email: email.to_s.strip.downcase, access_revoked_at: nil)
     end

     def start_session(user)
          reset_session
          session[:user_id] = user.id
          redirect_to root_path, notice: "Welcome back, #{user.name}."
     end
end
