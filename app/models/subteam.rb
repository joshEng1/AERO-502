class Subteam < ApplicationRecord
     include Archivable
     belongs_to :team
     has_many :memberships, dependent: :restrict_with_error
     has_many :users, through: :memberships
     has_many :projects, through: :team
     validates :name, presence: true, uniqueness: { scope: :team_id, case_sensitive: false }
     validate :assignments_remain_in_team

     def tasks
          Task.where(id: TaskAssignment.active.where(user_id: memberships.select(:user_id)).select(:task_id))
     end

     def full_name
          "#{team.name} · #{name}"
     end

     private

     def assignments_remain_in_team
          return unless persisted? && will_save_change_to_team_id?
          return unless TaskAssignment.active.where(user_id: memberships.select(:user_id)).joins(task: :project).where.not(projects: { team_id: team_id }).exists?

          errors.add(:team, "would invalidate active assignments")
     end
end
