class RostersController < ApplicationController
     before_action :require_sign_in
     before_action :set_subteam
     before_action :ensure_can_manage

     def update
          transfer_to(@subteam)
     end

     # Removing a membership requires a destination: non-admins always have one.
     def destroy
          destination = Subteam.active.find_by(id: params[:destination_subteam_id], team_id: @subteam.team_id)
          return roster_error("Choose a destination subteam to transfer this membership.") unless destination

          transfer_to(destination, source: @subteam)
     end

     private

     def transfer_to(destination, source: nil)
          member = User.assignable.in_teams(@subteam.team_id).find_by(id: params[:user_id])
          return roster_error("Choose an approved member or officer from this class.") unless member

          User.transaction do
               User.connection.execute("SELECT pg_advisory_xact_lock(5023001)")
               member.lock!
               if source && member.subteam_id != source.id
                    return roster_error("This person does not belong to this roster.")
               end
               member.update!(subteam: destination)
          end
          redirect_to subteam_path(@subteam), notice: "Membership transferred to #{destination.name}. Their account, assignments, history and hours are kept."
     rescue ActiveRecord::RecordInvalid => error
          roster_error(error.record.errors.full_messages.to_sentence)
     end

     def set_subteam
          @subteam = Subteam.find(params[:subteam_id])
     end

     def ensure_can_manage
          return if current_user.chief_engineer? || (current_user.officer? && current_user.team_id == @subteam.team_id)

          deny_access("Access denied. Only authorized leaders can manage this roster.")
     end

     def roster_error(message)
          redirect_to subteam_path(@subteam), alert: message
     end
end
