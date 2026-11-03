class TimelinesController < ApplicationController
     include TaskFiltering

     before_action :require_sign_in
     before_action :ensure_leader

     def show
          tasks = task_filter.apply(Task.accessible_to(current_user)).includes(:team, :subteam, :assignees).to_a
          @timeline = TaskTimeline.new(tasks: tasks)
          if request.format.csv?
               report = TaskReport.new(user: current_user, filter: task_filter, tasks: Task.where(id: tasks.map(&:id)))
               send_data ReportCsv.tasks(report), filename: "timeline.csv", type: "text/csv; charset=utf-8"
          end
     end

     private

     def ensure_leader
          return if current_user.leader?

          redirect_to tasks_path, alert: "Access denied. The timeline is available to team officers and the Chief Engineer."
     end
end
