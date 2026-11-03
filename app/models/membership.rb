class Membership < ApplicationRecord
     self.primary_key = :user_id
     belongs_to :user, inverse_of: :membership
     belongs_to :subteam
     validates :user_id, uniqueness: true
     validate :eligible_role_and_assignments

     private

     def eligible_role_and_assignments
          errors.add(:user, "cannot be an administrator") if user&.chief_engineer?
          return unless user && subteam
          return unless TaskAssignment.active.where(user_id: user.id).joins(task: :project).where.not(projects: { team_id: subteam.team_id }).exists?

          errors.add(:subteam, "would invalidate active assignments; resolve them before transferring teams")
     end
end
