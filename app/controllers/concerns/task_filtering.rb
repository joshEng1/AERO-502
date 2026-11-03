# Filters chosen on any task view are kept in the session so they stay
# applied when moving between the board, My Tasks and the dashboard.
module TaskFiltering
     extend ActiveSupport::Concern

     included do
          helper_method :task_filter
     end

     private

     def task_filter
          @task_filter ||= begin
               if params[:filter].present?
                    session[:task_filters] = TaskFilter.new(params[:filter].permit(*TaskFilter::KEYS, team_ids: [], project_ids: [])).to_h
               end
               TaskFilter.new(session[:task_filters] || default_task_filters)
          end
     end

     # A member's views open on their own team and subteam until they change it.
     def default_task_filters
          return {} unless current_user.member?

          session[:task_filters] = { "team_id" => current_user.team_id, "subteam_id" => current_user.subteam_id }.compact
     end
end
