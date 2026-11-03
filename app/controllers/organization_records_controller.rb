# Shared actions for teams, subteams and projects: create, rename, archive,
# restore, and a record page listing the group's tasks and hours. A record's
# parent is chosen when it is created and stays fixed afterwards.
class OrganizationRecordsController < ApplicationController
     before_action :require_sign_in
     before_action :ensure_leader
     before_action :set_record, only: %i[show edit update archive restore]
     before_action :ensure_can_manage_record, only: %i[show edit update archive restore]

     helper_method :parent_field, :parent_options, :record_label

     def show
          @tasks = @record.tasks.includes(:time_entries, project: :team).order(:due_date, :title)
          render "organization/record"
     end

     def new
          @record = model_class.new(parent_field ? { parent_field => params[parent_field] } : {})
          return deny_organization_access unless can_start?(@record)

          render "organization/form"
     end

     def create
          @record = model_class.new(params.require(param_key).permit(:name, *parent_field))
          return deny_organization_access unless can_manage?(@record)

          save_record("created")
     end

     def edit
          render "organization/form"
     end

     def update
          @record.assign_attributes(params.require(param_key).permit(:name))
          save_record("updated")
     end

     def archive
          @record.archive!
          redirect_to organization_path, notice: "#{record_label} “#{@record.name}” was archived."
     end

     def restore
          @record.restore!
          redirect_to organization_path, notice: "#{record_label} “#{@record.name}” was restored."
     end

     private

     def ensure_leader
          deny_access unless current_user.leader?
     end

     def set_record
          @record = model_class.find(params[:id])
     end

     def ensure_can_manage_record
          deny_organization_access unless can_manage?(@record)
     end

     def deny_organization_access
          redirect_to organization_path, alert: "You can manage only your own team's subteams and projects."
     end

     def save_record(verb)
          if @record.save
               redirect_to organization_path, notice: "#{record_label} “#{@record.name}” was #{verb}."
          else
               render "organization/form", status: :unprocessable_entity
          end
     end

     def param_key
          model_class.model_name.param_key
     end

     def record_label
          model_class.model_name.human
     end

     # The Chief Engineer manages everything; officers only what subclasses allow
     # inside their own team.
     def can_manage?(record)
          return true if current_user.chief_engineer?

          officer_managed? && team_id_for(record) == current_user.team_id
     end

     # Officers may open a blank form; its parent choices are limited to their team.
     def can_start?(record)
          can_manage?(record) || (officer_managed? && team_id_for(record).nil?)
     end

     def officer_managed?
          true
     end

     # Parent choices for a new record: everything for the Chief Engineer,
     # only the officer's own team otherwise.
     def team_ids_for_choices
          current_user.chief_engineer? ? Team.active.select(:id) : [ current_user.team_id ]
     end
end
