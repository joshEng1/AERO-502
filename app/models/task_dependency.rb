class TaskDependency < ApplicationRecord
     self.primary_key = [ :task_id, :prerequisite_task_id ]
     belongs_to :task
     belongs_to :prerequisite_task, class_name: "Task"
     validates :prerequisite_task_id, uniqueness: { scope: :task_id }
     validate :same_team_without_cycle

     private

     def same_team_without_cycle
          return unless task && prerequisite_task
          if task_id == prerequisite_task_id
               errors.add(:prerequisite_task, "cannot be the task itself")
          elsif task.team_id != prerequisite_task.team_id
               errors.add(:prerequisite_task, "must belong to the same team")
          elsif task_id && reaches_task?
               errors.add(:prerequisite_task, "would create a loop")
          end
     end

     def reaches_task?
          sql = self.class.sanitize_sql_array([ <<~SQL, prerequisite_task_id, task_id ])
               WITH RECURSIVE ancestors(id) AS (
                    SELECT prerequisite_task_id FROM task_dependencies WHERE task_id = ?
                    UNION SELECT d.prerequisite_task_id FROM task_dependencies d JOIN ancestors a ON d.task_id = a.id
               ) SELECT 1 FROM ancestors WHERE id = ? LIMIT 1
          SQL
          self.class.connection.select_value(sql)
     end
end
