class ReportsController < ApplicationController
     include TaskFiltering
     before_action :require_sign_in
     before_action :ensure_leader

     def member_hours
          report = TaskReport.new(user: current_user, filter: task_filter, from: params[:from], to: params[:to])
          project = Project.find_by(id: task_filter.project_id)
          send_data ReportCsv.members(report, project_name: project&.name || "All selected projects"), filename: "member-hours.csv", type: "text/csv; charset=utf-8"
     end

     def project_hours
          report = TaskReport.new(user: current_user, filter: task_filter, from: params[:from], to: params[:to])
          send_data ReportCsv.projects(report), filename: "project-hours.csv", type: "text/csv; charset=utf-8"
     end

     private

     def ensure_leader
          deny_access("Access denied. Reports are available to team officers and the Chief Engineer.") unless current_user.leader?
     end
end
