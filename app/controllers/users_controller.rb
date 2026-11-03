class UsersController < ApplicationController
     before_action :require_sign_in
     before_action :ensure_chief_engineer
     before_action :set_user, only: %i[edit update revoke restore]

     def index
          @users = User.includes(membership: { subteam: :team }).order(:name)
     end

     # Adds a person to the allowed list; they sign in with Google using this email.
     def new
          @user = User.new(role: :member)
     end

     def create
          @user = User.new(user_params.merge(params.require(:user).permit(:name, :email)))
          assign_role
          if @user.save
               redirect_to users_path, notice: "#{@user.name} can now sign in with #{@user.email}."
          else
               render :new, status: :unprocessable_entity
          end
     end

     def edit
     end

     def update
          @user.assign_attributes(user_params)
          assign_role
          if @user.save
               redirect_to users_path, notice: "#{@user.name} is now #{@user.role_with_article}."
          else
               render :edit, status: :unprocessable_entity
          end
     end

     def revoke
          if @user.update(access_revoked_at: Time.current)
               redirect_to users_path, notice: "#{@user.name} can no longer sign in. Their tasks and hours are kept."
          else
               redirect_to users_path, alert: @user.errors.full_messages.to_sentence
          end
     end

     def restore
          @user.update!(access_revoked_at: nil)
          redirect_to users_path, notice: "#{@user.name} can sign in again."
     end

     private

     def ensure_chief_engineer
          deny_access("Access denied. Only the Chief Engineer can manage people and roles.") unless current_user.chief_engineer?
     end

     def set_user
          @user = User.find(params[:id])
     end

     # Only the Chief Engineer reaches these actions (see ensure_chief_engineer).
     def assign_role
          @user.role = params.require(:user).fetch(:role, @user.role)
          @user.subteam = nil if @user.chief_engineer? && !params.require(:user).key?(:subteam_id)
     end

     def user_params
          params.require(:user).permit(:team_id, :subteam_id)
     end
end
