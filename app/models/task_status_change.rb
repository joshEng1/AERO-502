class TaskStatusChange < ApplicationRecord
     belongs_to :task
     belongs_to :actor, class_name: "User"
     enum :to_status, { backlog: 0, in_progress: 1, completed: 2 }, validate: true
     validates :created_at, presence: true
     validate :actor_can_change_status

     def readonly?
          persisted?
     end

     private

     def actor_can_change_status
          return if actor && task && (actor.can_manage?(task) || actor.can_work_on?(task))

          errors.add(:actor, "must be authorized to change this task")
     end
end
