require "rails_helper"

# Scope S01/S03: a task belongs to a project; its subteam and team come from that project.
RSpec.describe "Task projects", type: :request do
     def task_params(project, overrides = {})
          { title: "Fit wing spar", start_date: "2026-10-01", due_date: "2026-10-20", estimated_hours: "2", project_id: project.id }.merge(overrides)
     end

     it "fills in the task's subteam and team from the chosen project, ignoring other values" do
          sign_in(users(:chief))
          post tasks_path, params: { task: task_params(projects(:airframe_build),
                                                       team_id: teams(:aerodynamics).id, subteam_id: subteams(:wing).id) }

          task = Task.order(:id).last
          expect([ task.subteam, task.team ]).to eq([ subteams(:airframe), teams(:structures) ])
     end

     it "moves the task's subteam and team when a leader changes its project" do
          new_project = Project.create!(name: "Wing tips", subteam: subteams(:wing))
          sign_in(users(:officer))
          patch task_path(tasks(:wing_test)), params: { task: { project_id: new_project.id } }

          expect(tasks(:wing_test).reload).to have_attributes(project: new_project, subteam: subteams(:wing),
                                                               team: teams(:aerodynamics))
     end

     it "lists projects as Team · Subteam · Project and limits officers to their own team" do
          sign_in(users(:officer))
          get new_task_path

          expect(response.parsed_body.css("#task_project_id option").map(&:text))
               .to eq([ "Select a project", "Aerodynamics · Wing Analysis · Archive Project",
                        "Aerodynamics · Wing Analysis · SAE AERO Design" ])
          expect(response.parsed_body.at_css("#task_team_id, #task_subteam_id")).to be_nil
     end

     it "refuses an officer's task in another team's project" do
          sign_in(users(:officer))

          expect { post tasks_path, params: { task: task_params(projects(:airframe_build)) } }.not_to change(Task, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.at_css("#task_project_error").text).to include("Project must belong to your team")
     end

     it "requires a project" do
          sign_in(users(:officer))

          expect { post tasks_path, params: { task: task_params(projects(:aero), project_id: "") } }.not_to change(Task, :count)
          expect(response.parsed_body.at_css("#task_project_error").text).to include("Project must exist")
     end
end
