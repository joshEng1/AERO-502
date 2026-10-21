require "rails_helper"

RSpec.describe "KAN-7, KAN-9, and KAN-12 delivered access and status", type: :request do
     def sign_in_as(user)
          post login_path, params: { email: user.email, password: "password" }
          expect(response).to redirect_to(root_path)
     end

     def create_unassigned_team_task
          Task.create!(
               title: "Unassigned wind tunnel calibration",
               description: "Calibrate the tunnel before testing.",
               estimated_hours: 2,
               start_date: Date.new(2026, 10, 1),
               due_date: Date.new(2026, 10, 20),
               status: :backlog,
               project: projects(:aero),
               team: teams(:aerodynamics),
               creator: users(:officer)
          )
     end

     it "requires authentication for the dashboard, board, task detail, and status update" do
          [ root_path, tasks_path, task_path(tasks(:wing_test)) ].each do |path|
               get path
               expect(response).to redirect_to(login_path)
          end

          patch task_path(tasks(:wing_test)), params: { task: { status: "completed" } }
          expect(response).to redirect_to(login_path)
          expect(tasks(:wing_test).reload).to be_backlog
     end

     it "keeps failed credentials signed out" do
          post login_path, params: { email: users(:member).email, password: "incorrect" }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Email or password is incorrect")

          get root_path
          expect(response).to redirect_to(login_path)
     end

     it "shows chief engineers both teams and permits cross-team management" do
          sign_in_as(users(:chief))

          [ root_path, tasks_path, task_path(tasks(:spar_check)), edit_task_path(tasks(:spar_check)) ].each do |path|
               get path
               expect(response).to have_http_status(:ok)
          end

          get tasks_path
          expect(response.body).to include("Wing load test", "Verify spar dimensions", "New Task")
     end

     it "shows officers only their team and denies cross-team management" do
          sign_in_as(users(:officer))

          [ root_path, tasks_path ].each do |path|
               get path
               expect(response).to have_http_status(:ok)
               expect(response.body).to include("Wing load test")
               expect(response.body).not_to include("Verify spar dimensions")
          end

          get edit_task_path(tasks(:wing_test))
          expect(response).to have_http_status(:ok)
          get edit_task_path(tasks(:spar_check))
          expect(response).to redirect_to(root_path)
          patch task_path(tasks(:spar_check)), params: { task: { title: "Unauthorized edit" } }
          expect(response).to redirect_to(root_path)
          expect(tasks(:spar_check).reload.title).to eq("Verify spar dimensions")
     end

     it "shows members only assigned tasks, including on the dashboard and board" do
          unassigned = create_unassigned_team_task
          sign_in_as(users(:member))

          [ root_path, tasks_path, tasks_path(view: "mine") ].each do |path|
               get path
               expect(response).to have_http_status(:ok)
               expect(response.body).to include("Wing load test")
               expect(response.body).not_to include(unassigned.title, "Verify spar dimensions", "Create task")
          end

          get task_path(tasks(:wing_test))
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Update status")
          expect(response.body).not_to include("Edit task")
     end

     it "blocks direct reads and updates of a same-team task without an assignment" do
          unassigned = create_unassigned_team_task
          sign_in_as(users(:member))

          get task_path(unassigned)
          expect(response).to redirect_to(root_path)
          patch task_path(unassigned), params: { task: { status: "completed" } }
          expect(response).to redirect_to(root_path)
          expect(unassigned.reload).to be_backlog
     end

     it "persists each assigned status transition and displays it on fresh detail, board, and dashboard requests" do
          task = tasks(:wing_test)
          sign_in_as(users(:member))
          expect(task).to be_backlog

          { "in_progress" => "In progress", "completed" => "Completed" }.each do |status, label|
               patch task_path(task), params: { task: { status: status } }
               expect(response).to redirect_to(task_path(task))
               expect(task.reload.status).to eq(status)

               get task_path(task)
               expect(response).to have_http_status(:ok)
               expect(response.body).to include("status-#{status}", label)

               get tasks_path
               expect(response).to have_http_status(:ok)
               column = Nokogiri::HTML(response.body).css(".task-column").find do |entry|
                    entry.at_css(".column-heading h2")&.[]("id") == "#{status}-heading"
               end
               expect(column).not_to be_nil
               expect(column.text).to include(task.title)
          end
     end

     it "lets assigned members change status without changing other task fields or assignments" do
          task = tasks(:wing_test)
          original_assignees = task.assignee_ids
          sign_in_as(users(:member))

          patch task_path(task), params: {
               task: {
                    status: "completed",
                    title: "Tampered title",
                    estimated_hours: 0,
                    team_id: teams(:structures).id,
                    assignee_ids: [ users(:other_member).id ]
               }
          }

          expect(response).to redirect_to(task_path(task))
          expect(task.reload).to be_completed
          expect(task.title).to eq("Wing load test")
          expect(task.estimated_hours).to eq(10)
          expect(task.team).to eq(teams(:aerodynamics))
          expect(task.assignee_ids).to match_array(original_assignees)
     end
end
