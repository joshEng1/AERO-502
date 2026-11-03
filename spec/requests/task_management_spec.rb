require "rails_helper"

RSpec.describe "Task management", type: :request do
     def sign_in_as(role)
          post login_path, params: { email: users(role).email, password: "password" }
     end

     it "shows login, redirects signed-in users, and revokes access after logout" do
          get login_path
          expect(response).to have_http_status(:ok)
          sign_in_as(:member)
          get login_path
          expect(response).to redirect_to(root_path)
          delete logout_path
          expect(response).to redirect_to(login_path)
          get root_path
          expect(response).to redirect_to(login_path)
     end

     it "shows only assigned work on the member board and detail page" do
          sign_in_as(:member)
          [ tasks_path, tasks_path(view: "mine"), task_path(tasks(:wing_test)) ].each do |path|
               get path
               expect(response).to have_http_status(:ok)
               expect(response.body).to include("Wing load test")
               expect(response.body).not_to include("Verify spar dimensions")
          end
     end

     it "prevents members from creating tasks, updating unassigned work, or logging others' hours" do
          sign_in_as(:member)
          get new_task_path
          expect(response).to redirect_to(root_path)
          patch task_path(tasks(:spar_check)), params: { task: { status: "completed" } }
          expect(response).to redirect_to(root_path)
          expect(tasks(:spar_check).reload.status).to eq("in_progress")
          expect do
               post task_time_entries_path(tasks(:spar_check)), params: { time_entry: { hours: 1 } }
          end.not_to change(TimeEntry, :count)
          expect(response).to redirect_to(root_path)
     end

     it "renders a validation error for a blank member status" do
          sign_in_as(:member)
          patch task_path(tasks(:wing_test)), params: { task: { status: "" } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(tasks(:wing_test).reload.status).to eq("backlog")
     end

     it "lets officers open forms and update their team's task" do
          sign_in_as(:officer)
          [ new_task_path, edit_task_path(tasks(:wing_test)) ].each do |path|
               get path
               expect(response).to have_http_status(:ok)
          end
          patch task_path(tasks(:wing_test)), params: { task: { title: "Updated wing test", assignee_ids: [ users(:member).id ] } }
          expect(response).to redirect_to(task_path(tasks(:wing_test)))
          expect(tasks(:wing_test).reload.title).to eq("Updated wing test")
     end

     it "rejects invalid task creation and updates without persisting them" do
          sign_in_as(:officer)
          expect do
               post tasks_path, params: { task: { title: "", project_id: projects(:aero).id } }
          end.not_to change(Task, :count)
          expect(response).to have_http_status(:unprocessable_content)
          patch task_path(tasks(:wing_test)), params: { task: { title: "" } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(tasks(:wing_test).reload.title).to eq("Wing load test")
     end

     it "rolls back edits when an assignee belongs to another team" do
          sign_in_as(:officer)
          patch task_path(tasks(:wing_test)), params: {
               task: { title: "Invalid assignment", assignee_ids: [ users(:other_member).id ] }
          }
          expect(response).to have_http_status(:unprocessable_content)
          expect(tasks(:wing_test).reload.title).to eq("Wing load test")
          expect(tasks(:wing_test).assignees).to include(users(:member))
     end

     it "lets chief engineers open cross-team forms and preserve the initial history of a new task" do
          sign_in_as(:chief)
          get edit_task_path(tasks(:spar_check))
          expect(response).to have_http_status(:ok)
          task = Task.create!(title: "Unused task", start_date: Date.current, due_date: Date.current,
                              estimated_hours: 0, project: projects(:aero), creator: users(:chief))
          expect do
               delete task_path(task)
          end.not_to change(Task, :count)
          expect(response).to redirect_to(task_path(task))
     end
end
