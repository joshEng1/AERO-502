class TasksController < ApplicationController
     include TaskFiltering
     OWN_TEAM_ONLY = "You can manage only tasks on your own team.".freeze
     before_action :require_sign_in
     before_action :set_task, only: %i[show edit update destroy]
     before_action :ensure_can_view_task, only: :show
     before_action :ensure_leader, only: %i[new create]
     before_action :ensure_can_manage_task, only: %i[edit destroy]

     def index
          if request.format.csv? && !current_user.leader?
               return deny_access("Access denied. Reports are available to team officers and the Chief Engineer.")
          end
          @tasks = task_filter.apply(Task.accessible_to(current_user))
                              .includes(:project, :team, :subteams, :assignees, :prerequisites, time_entries: :user)
                              .order(:status, :due_date, :title)
          @view = params[:view] == "mine" ? "mine" : "board"
          @tasks = @tasks.where(id: current_user.active_assignments.select(:task_id)) if @view == "mine"
          return unless current_user.leader?

          report = TaskReport.new(user: current_user, filter: task_filter, tasks: @tasks, from: params[:from], to: params[:to])
          return send_data(ReportCsv.tasks(report), filename: "tasks.csv", type: "text/csv; charset=utf-8") if request.format.csv?

          @hours = report.hours if @view == "board"
     end

     def show
          @time_entry = TimeEntry.new(worked_on: Date.current)
     end

     def new
          status = Task.statuses.key?(params[:status]) ? params[:status] : :backlog
          @task = Task.new(status: status, project_id: task_filter.single_project_id)
          prepare_form
     end

     def create
          @task = Task.new(task_attributes)
          @task.creator = current_user
          restrict_task_to_officer_team
          if save_task_with_assignments
               finish_save("created")
          else
               prepare_form
               render :new, status: :unprocessable_entity
          end
     end

     def edit
          prepare_form
     end

     def update
          return update_status_as_member unless current_user.can_manage?(@task)

          @task.assign_attributes(task_attributes)
          @task.acting_user = current_user
          restrict_task_to_officer_team
          if save_task_with_assignments
               finish_save("updated")
          else
               prepare_form
               render :edit, status: :unprocessable_entity
          end
     end

     def destroy
          redirect_to @task, alert: "Tasks with recorded history or logged hours cannot be deleted."
     end

     private

     def set_task
          @task = Task.find(params[:id])
     end

     def ensure_can_view_task
          deny_access("You cannot view that task.") unless Task.accessible_to(current_user).exists?(@task.id)
     end

     def ensure_leader
          deny_access unless current_user.leader?
     end

     def ensure_can_manage_task
          deny_access(OWN_TEAM_ONLY) unless current_user.can_manage?(@task)
     end

     def update_status_as_member
          return deny_access(OWN_TEAM_ONLY) if current_user.leader?
          return deny_access("You can update only tasks assigned to you.") unless current_user.can_work_on?(@task)
          if params.require(:task).key?(:prerequisite_ids)
               return deny_access("Members may update only the status of their assigned tasks.")
          end

          @task.acting_user = current_user
          if @task.update(params.require(:task).permit(:status))
               redirect_to @task, notice: "Task status was updated."
          else
               @time_entry = TimeEntry.new(worked_on: Date.current)
               render :show, status: :unprocessable_entity
          end
     end

     def task_params
          params.require(:task).permit(
               :title, :description, :instructions, :reference_links_text, :start_date, :due_date,
               :estimated_hours, :status, :project_id, :primary_contact_id,
               assignee_ids: [], prerequisite_ids: []
          )
     end

     def task_attributes
          task_params.except(:assignee_ids, :prerequisite_ids, :primary_contact_id)
     end

     def restrict_task_to_officer_team
          @task.allowed_team_id = current_user.team_id if current_user.officer?
     end

     def save_task_with_assignments
          Task.transaction do
               @task.save!
               @task.assign_members(task_params[:assignee_ids], actor: current_user) if task_params.key?(:assignee_ids)
               @task.designate_primary_contact(task_params[:primary_contact_id]) if task_params.key?(:primary_contact_id)
               @task.replace_prerequisites(task_params[:prerequisite_ids], actor: current_user) if task_params.key?(:prerequisite_ids)
          end
          true
     rescue ActiveRecord::RecordInvalid => error
          @task.errors.merge!(error.record.errors) unless error.record == @task
          false
     end

     def finish_save(verb)
          if params[:return_to_board] == "1"
               flash[:unassigned_project_id] = @task.project_id if @task.assignee_ids.empty?
               redirect_to tasks_path(filter: task_filter.to_h), notice: "Task was #{verb} successfully."
          else
               redirect_to @task, notice: "Task was #{verb} successfully."
          end
     end

     def prepare_form
          team_ids = current_user.chief_engineer? ? Team.select(:id) : [ current_user.team_id ]
          active = Project.active.joins(:team).merge(Team.active).where(team_id: team_ids)
          current = Project.where(id: @task.persisted? ? @task.project_id : nil, team_id: team_ids)
          @projects = (active.includes(:team).to_a | current.includes(:team).to_a).sort_by(&:full_name)
          existing = User.where(id: @task.assignee_ids).in_teams(team_ids)
          @assignees = (User.assignable.in_teams(team_ids).includes(membership: :subteam).to_a | existing.includes(membership: :subteam).to_a).sort_by { |person| [ person.name, person.id ] }
          @prerequisites = Task.accessible_to(current_user).in_active_projects.where.not(id: @task.id).includes(:project).order(:title, :id)
          submitted = params[:task]
          @selected_assignee_ids = submitted&.key?(:assignee_ids) ? Array(task_params[:assignee_ids]).map(&:to_i) : @task.assignee_ids
          @selected_prerequisite_ids = submitted&.key?(:prerequisite_ids) ? Array(task_params[:prerequisite_ids]).map(&:to_i) : @task.prerequisite_ids
          @primary_contact_id = submitted&.key?(:primary_contact_id) ? task_params[:primary_contact_id] : @task.primary_contact_id
     end
end
