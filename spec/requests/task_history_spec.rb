require "rails_helper"

# KAN-20: leaders see who assigned work and changed its status.
RSpec.describe "Task history", type: :request do
     let(:task) { tasks(:wing_test) }
     let(:second_member) do
          User.create!(name: "Sam Second", email: "sam@example.test", password: "password",
                       role: :member, team: teams(:aerodynamics))
     end

     def history_items
          response.parsed_body.css("[data-history] li").map { |item| item.text.squish }
     end

     it "records assignments and removals with the actor and the affected member" do
          sign_in(users(:officer))

          expect do
               patch task_path(task), params: { task: { assignee_ids: [ second_member.id ] } }
          end.to change(TaskEvent, :count).by(2)

          events = TaskEvent.where(task: task).order(:id).last(2)
          expect(events.map { |event| [ event.action, event.subject_user, event.actor ] }).to contain_exactly(
               [ "assigned", second_member, users(:officer) ], [ "unassigned", users(:member), users(:officer) ]
          )
     end

     it "records assignments made when a task is created" do
          sign_in(users(:officer))
          post tasks_path, params: { task: {
               title: "New task", start_date: "2026-10-01", due_date: "2026-10-20", estimated_hours: "1", project_id: projects(:aero).id,
               team_id: teams(:aerodynamics).id, assignee_ids: [ users(:member).id ]
          } }

          event = TaskEvent.order(:id).last
          expect(event).to have_attributes(action: "assigned", subject_user: users(:member), actor: users(:officer))
     end

     it "does not record anything when the assignees are unchanged" do
          sign_in(users(:officer))

          expect do
               patch task_path(task), params: { task: { title: "Renamed", assignee_ids: [ users(:member).id ] } }
          end.not_to change(TaskEvent, :count)
     end

     it "shows the history newest first on the task page, in plain text" do
          travel_to(Time.zone.local(2026, 10, 1, 9, 0)) do
               sign_in(users(:member))
               patch task_path(task), params: { task: { status: "in_progress" } }
          end
          travel_to(Time.zone.local(2026, 10, 2, 14, 30)) do
               sign_in(users(:officer))
               patch task_path(task), params: { task: { assignee_ids: [ users(:member).id, second_member.id ] } }
          end

          get task_path(task)
          expect(history_items).to eq([
               "October 02, 2026 14:30 Olivia Officer assigned Sam Second",
               "October 01, 2026 09:00 Morgan Member changed the status from Backlog to In progress"
          ])
     end

     it "explains when a task has no history yet" do
          sign_in(users(:officer))
          get task_path(task)

          expect(response.parsed_body.at_css("[data-history]").text).to include("No changes have been recorded yet.")
     end

     it "shows history only to leaders who manage the task" do
          TaskEvent.create!(task: task, actor: users(:member), action: "status_changed",
                            from_status: "backlog", to_status: "in_progress")

          sign_in(users(:chief))
          get task_path(task)
          expect(history_items.size).to eq(1)

          sign_in(users(:member))
          get task_path(task)
          expect(response.parsed_body.at_css("[data-history]")).to be_nil
     end

     it "cannot be changed or deleted once saved" do
          event = TaskEvent.create!(task: task, actor: users(:member), action: "status_changed",
                                    from_status: "backlog", to_status: "in_progress")

          expect { event.update!(to_status: "completed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
          expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
          expect(Rails.application.routes.named_routes.names.grep(/event/)).to be_empty
     end

     it "keeps recorded history when a leader tries to delete its task" do
          event = TaskEvent.create!(task: task, actor: users(:member), action: "status_changed",
                                    from_status: "backlog", to_status: "in_progress")
          sign_in(users(:chief))

          expect { delete task_path(task) }.not_to change(TaskEvent, :count)
          expect(response).to redirect_to(task_path(task))
          expect(flash[:alert]).to include("cannot be deleted")
          expect(task.reload).to be_persisted
          expect(event.reload).to be_persisted
          expect { task.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
     end

     it "keeps logged hours when a task has no event history" do
          sign_in(users(:chief))
          task = tasks(:spar_check)
          expect(task.events).to be_empty

          expect { delete task_path(task) }.not_to change(TimeEntry, :count)
          expect(response).to redirect_to(task_path(task))
          expect(task.reload).to be_persisted
          expect(time_entries(:spar_hours).reload).to be_persisted
     end
end
