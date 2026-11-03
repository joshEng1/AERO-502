class TaskAssignment < ApplicationRecord
     belongs_to :task
     belongs_to :user
     belongs_to :assigned_by, class_name: "User"
     belongs_to :unassigned_by, class_name: "User", optional: true
     scope :active, -> { where(unassigned_at: nil) }
     validates :assigned_at, presence: true
     validates :user_id, uniqueness: { scope: :task_id, conditions: -> { active } }, if: -> { unassigned_at.nil? }
     validate :assignee_belongs_to_task_team
     validate :ending_is_complete

     private

     def assignee_belongs_to_task_team
          return if unassigned_at || task.blank? || user.blank?
          return if !user.chief_engineer? && user.subteam && user.team_id == task.team_id

          errors.add(:user, "must belong to the task's team and have a subteam membership")
     end

     def ending_is_complete
          if unassigned_at.nil? != unassigned_by_id.nil? || (unassigned_at && assigned_at && unassigned_at < assigned_at)
               errors.add(:unassigned_at, "must include an authorized remover and be on or after assignment")
          end
          errors.add(:is_primary_contact, "requires an active assignment") if is_primary_contact && unassigned_at
     end
end
