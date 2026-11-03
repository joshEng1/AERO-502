require "rails_helper"

# KAN-12: assigned members move their tasks between Backlog, In Progress and
# Completed, and every successful status change is recorded as an event.
RSpec.describe "Task status updates", type: :request do
     it "moves an assigned member's task to the chosen column and keeps it there after refreshing" do
          sign_in(users(:member))
          patch task_path(tasks(:wing_test)), params: { task: { status: "in_progress" } }
          expect(response).to redirect_to(task_path(tasks(:wing_test)))

          get tasks_path
          in_progress = response.parsed_body.at_css("#in_progress-heading").ancestors("section").first
          expect(in_progress.text).to include("Wing load test")

          patch task_path(tasks(:wing_test)), params: { task: { status: "completed" } }
          get tasks_path
          completed = response.parsed_body.at_css("#completed-heading").ancestors("section").first
          expect(completed.text).to include("Wing load test")
          expect(tasks(:wing_test).reload).to be_completed
     end

     it "records the actor, old status, new status and time of each change" do
          sign_in(users(:member))

          freeze_time do
               expect do
                    patch task_path(tasks(:wing_test)), params: { task: { status: "in_progress" } }
               end.to change(TaskStatusChange, :count).by(1)

               expect(TaskStatusChange.order(:id).last).to have_attributes(
                    task: tasks(:wing_test), actor: users(:member),
                    to_status: "in_progress", created_at: Time.current
               )
          end
     end

     it "records status changes made by a leader on the edit form" do
          sign_in(users(:officer))

          expect do
               patch task_path(tasks(:wing_test)), params: { task: { status: "completed" } }
          end.to change(TaskStatusChange, :count).by(1)
          expect(TaskStatusChange.order(:id).last.actor).to eq(users(:officer))
     end

     it "does not record an event when the status is unchanged or the change fails" do
          sign_in(users(:member))

          expect do
               patch task_path(tasks(:wing_test)), params: { task: { status: "backlog" } }
               patch task_path(tasks(:wing_test)), params: { task: { status: "" } }
               patch task_path(tasks(:wing_test)), params: { task: { status: "archived" } }
          end.not_to change(TaskStatusChange, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(tasks(:wing_test).reload).to be_backlog
     end

     it "keeps every task in exactly one of the three statuses" do
          task = tasks(:wing_test)
          task.status = "archived"

          expect(task).not_to be_valid
          expect(Task.statuses.keys).to eq(%w[backlog in_progress completed])
     end

     it "gives unassigned members no way to change the status and records nothing" do
          sign_in(users(:other_member))

          expect do
               patch task_path(tasks(:wing_test)), params: { task: { status: "completed" } }
          end.not_to change(TaskStatusChange, :count)
          expect(response).to redirect_to(root_path)
          expect(tasks(:wing_test).reload).to be_backlog
     end

     it "rolls back the status change when the event cannot be saved" do
          sign_in(users(:member))
          allow_any_instance_of(TaskStatusChange).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(TaskStatusChange.new))

          patch task_path(tasks(:wing_test)), params: { task: { status: "completed" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(tasks(:wing_test).reload).to be_backlog
     end
end
