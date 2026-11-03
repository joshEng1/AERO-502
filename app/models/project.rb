class Project < ApplicationRecord
     include Archivable
     belongs_to :team
     has_many :tasks, dependent: :restrict_with_error
     has_many :subteams, through: :team
     validates :name, presence: true, uniqueness: { scope: :team_id, case_sensitive: false }
     validate :assignments_remain_in_team

     def full_name
          "#{team.name} · #{name}"
     end

     private

     def assignments_remain_in_team
          return unless persisted? && will_save_change_to_team_id?
          invalid = TaskAssignment.active.where(task_id: tasks.select(:id)).joins(user: { membership: :subteam }).where.not(subteams: { team_id: team_id })
          errors.add(:team, "would invalidate active assignments") if invalid.exists?
          linked = TaskDependency.where(task_id: tasks.select(:id)).or(TaskDependency.where(prerequisite_task_id: tasks.select(:id)))
          errors.add(:team, "cannot change while tasks have prerequisites; resolve the links first") if linked.exists?
     end
end
