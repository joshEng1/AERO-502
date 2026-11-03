require "rails_helper"

RSpec.describe "Database history and prerequisite integrity" do
     def reject_write(&block)
          expect do
               ApplicationRecord.transaction(requires_new: true) do
                    block.call
                    ApplicationRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
               end
          end.to raise_error(ActiveRecord::StatementInvalid)
     end

     it "enforces active and primary uniqueness, complete endings and immutable periods on direct writes" do
          task = tasks(:wing_test)
          current = task_assignments(:wing_member)
          reject_write do
               TaskAssignment.insert_all!([ { task_id: task.id, user_id: users(:member).id, assigned_by_id: users(:chief).id, assigned_at: Time.current } ])
          end
          task.assign_members([ users(:member).id, users(:officer).id ], actor: users(:chief))
          task.designate_primary_contact(users(:member).id)
          reject_write { task.active_assignments.where(user_id: users(:officer).id).update_all(is_primary_contact: true) }
          reject_write { current.update_columns(unassigned_at: Time.current) }
          reject_write { current.update_columns(unassigned_by_id: users(:chief).id, unassigned_at: current.assigned_at - 1.second, is_primary_contact: false) }
          reject_write { current.update_columns(assigned_by_id: users(:member).id) }
          task.assign_members([ users(:officer).id ], actor: users(:chief))
          reject_write { current.update_columns(unassigned_at: nil, unassigned_by_id: nil) }
          reject_write { TaskAssignment.where(id: current.id).delete_all }
          expect(current.reload).to have_attributes(unassigned_by_id: users(:chief).id, is_primary_contact: false)
     end

     it "rejects status drift, unauthorized attribution, backdated changes and rewritten history" do
          task = tasks(:wing_test)
          reject_write { task.update_columns(status: 2) }
          rejected_rows = [
               { actor_id: users(:other_member).id, to_status: 1, created_at: Time.current },
               { actor_id: users(:chief).id, to_status: 0, created_at: Time.current },
               { actor_id: users(:chief).id, to_status: 1, created_at: task.created_at - 1.second }
          ]
          rejected_rows.each do |row|
               reject_write { TaskStatusChange.insert_all!([ row.merge(task_id: task.id) ]) }
          end
          reject_write { TaskStatusChange.where(task_id: task.id).update_all(actor_id: users(:chief).id) }
          reject_write { TaskStatusChange.where(task_id: task.id).delete_all }
          expect(task.reload).to be_backlog
          expect(task.status_changes.count).to eq(1)
     end

     it "enforces the creator and timestamp on the first status row" do
          reject_write do
               now = Time.current
               id = Task.insert_all!([ { title: "Forged creation", project_id: projects(:aero).id, creator_id: users(:chief).id,
                    status: 0, start_date: Date.current, due_date: Date.current, estimated_hours: 0, created_at: now, updated_at: now } ]).rows.first.first
               TaskStatusChange.insert_all!([ { task_id: id, actor_id: users(:officer).id, to_status: 0, created_at: now } ])
          end
     end

     it "rejects direct circular and cross-class dependencies without changing task dates or statuses" do
          task = tasks(:wing_test)
          first = Task.create!(title: "Prerequisite", project: projects(:aero), creator: users(:chief), due_date: Date.current, estimated_hours: 0)
          TaskDependency.create!(task: task, prerequisite_task: first)
          reject_write { TaskDependency.insert_all!([ { task_id: first.id, prerequisite_task_id: task.id } ]) }
          reject_write { TaskDependency.insert_all!([ { task_id: first.id, prerequisite_task_id: tasks(:spar_check).id } ]) }
          reject_write { TaskDependency.insert_all!([ { task_id: first.id, prerequisite_task_id: first.id } ]) }
          expect(task.reload).to be_backlog
          expect(task.due_date).to eq(Date.new(2026, 10, 5))
          expect(TaskDependency.count).to eq(1)
     end
end
