require "rails_helper"

RSpec.describe "Task history", type: :request do
     let(:task) { tasks(:wing_test) }
     let(:second_member) { User.create!(name: "Sam Second", email: "sam@example.test", role: :member, subteam: subteams(:wing)) }

     def history_items
          response.parsed_body.css("[data-history] li").map { |item| item.text.squish }
     end

     it "ends assignment periods with the remover and starts a new period on reassignment" do
          sign_in(users(:officer))
          original = task.active_assignments.first
          patch task_path(task), params: { task: { assignee_ids: [ second_member.id ] } }
          expect(original.reload).to have_attributes(assigned_by: users(:officer), unassigned_by: users(:officer))
          expect(original.unassigned_at).to be_present
          expect(task.active_assignments.first.user).to eq(second_member)
          patch task_path(task), params: { task: { assignee_ids: [ users(:member).id, second_member.id ] } }
          expect(task.task_assignments.where(user: users(:member)).count).to eq(2)
          expect(task.active_assignments.where(user: users(:member)).count).to eq(1)
          expect(task.time_entries.sum(:hours)).to eq(2.5)
     end

     it "records the initial status and creator when a task is created in any column" do
          sign_in(users(:officer))
          post tasks_path, params: { task: { title: "Created complete", project_id: projects(:aero).id,
               due_date: Date.current, estimated_hours: 1, status: "completed", assignee_ids: [ users(:member).id ] } }
          created = Task.order(:id).last
          expect(created.status_changes.first).to have_attributes(actor: users(:officer), to_status: "completed", created_at: created.created_at)
          expect(created.active_assignments.first.assigned_by).to eq(users(:officer))
     end

     it "does not add periods or status changes for unchanged fields" do
          sign_in(users(:officer))
          expect do
               patch task_path(task), params: { task: { title: "Renamed", status: "backlog", assignee_ids: [ users(:member).id ] } }
          end.not_to change { [ TaskAssignment.count, TaskStatusChange.count ] }
     end

     it "combines assignment and status history newest first with named actors" do
          travel_to(Time.zone.local(2026, 10, 1, 9, 0)) do
               sign_in(users(:member))
               patch task_path(task), params: { task: { status: "in_progress" } }
          end
          travel_to(Time.zone.local(2026, 10, 2, 14, 30)) do
               sign_in(users(:officer))
               patch task_path(task), params: { task: { assignee_ids: [ users(:member).id, second_member.id ] } }
          end
          get task_path(task)
          expect(history_items.first(2)).to eq([
               "October 02, 2026 14:30 Olivia Officer assigned Sam Second",
               "October 01, 2026 09:00 Morgan Member changed the status from Backlog to In progress"
          ])
          expect(history_items.last).to include("Olivia Officer created the task in Backlog")
     end

     it "shows the initial status to leaders and hides the history from members" do
          sign_in(users(:chief))
          get task_path(task)
          expect(history_items.last).to include("created the task")
          sign_in(users(:member))
          get task_path(task)
          expect(response.parsed_body.at_css("[data-history]")).to be_nil
     end

     it "keeps all history and logged hours when a leader tries to delete the task" do
          sign_in(users(:chief))
          expect { delete task_path(task) }.not_to change { [ Task.count, TaskAssignment.count, TaskStatusChange.count, TimeEntry.count ] }
          expect(response).to redirect_to(task_path(task))
          expect(flash[:alert]).to include("cannot be deleted")
          expect { task.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
     end

     it "prevents editing or deleting status history and rewriting assignment periods in SQL" do
          change = task_status_changes(:wing_initial)
          expect { change.update!(to_status: "completed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
          expect { change.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
          connection = ApplicationRecord.connection
          [
               "UPDATE task_status_changes SET to_status = 1 WHERE id = #{change.id}",
               "DELETE FROM task_status_changes WHERE id = #{change.id}",
               "DELETE FROM task_assignments WHERE task_id = #{task.id}",
               "UPDATE task_assignments SET assigned_by_id = #{users(:chief).id} WHERE task_id = #{task.id}"
          ].each do |sql|
               expect { ApplicationRecord.transaction(requires_new: true) { connection.execute(sql) } }.to raise_error(ActiveRecord::StatementInvalid)
          end
     end
end
