class OrganizationController < ApplicationController
     before_action :require_sign_in
     before_action -> { deny_access unless current_user.leader? }

     def show
          if current_user.chief_engineer?
               @teams = Team.active
               @archived = Team.archived.to_a + Subteam.archived.includes(:team).to_a +
                           Project.archived.includes(:team).to_a
          else
               @teams = Team.active.where(id: current_user.team_id)
               own_subteams = Subteam.where(team_id: current_user.team_id)
               @archived = own_subteams.archived.includes(:team).to_a +
                           Project.archived.where(team_id: current_user.team_id).includes(:team).to_a
          end
          @teams = @teams.includes(:projects, subteams: :projects).order(:name)
     end
end
