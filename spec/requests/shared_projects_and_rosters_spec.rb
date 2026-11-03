require "rails_helper"

RSpec.describe "Shared projects and subteam rosters", type: :request do
     let(:team) { teams(:aerodynamics) }
     let(:wing) { subteams(:wing) }
     let(:project) { projects(:aero) }
     let(:member) { users(:member) }
     let(:second) { Subteam.create!(team: team, name: "Propulsion") }
     let(:second_member) { User.create!(name: "Propulsion Member", email: "propulsion@tamu.edu", role: :member, subteam: second) }

     it "creates a team-owned project without selecting participating subteams" do
          second
          sign_in(users(:officer))
          post projects_path, params: { project: { name: "Shared aircraft", team_id: team.id } }
          shared = Project.find_by!(name: "Shared aircraft")
          expect(shared.subteams).to contain_exactly(wing, second)
          get new_project_path(team_id: team.id)
          expect(response.body).not_to include("Participating subteams")
          expect(response.parsed_body.css('[name="project[subteam_ids][]"]')).to be_empty
     end

     it "shows one shared task once on each assignee's subteam board and once in the combined view" do
          task = tasks(:wing_test)
          task.assign_members([ member.id, second_member.id, users(:officer).id ], actor: users(:officer))
          sign_in(users(:officer))
          [ wing.id, second.id, nil ].each do |subteam_id|
               get tasks_path(filter: { project_id: project.id, subteam_id: subteam_id })
               expect(response.parsed_body.css(".task-card h3 a").map { |link| link["href"] }).to eq([ task_path(task) ])
          end
          get timeline_path(filter: { project_id: project.id })
          expect(response.parsed_body.css("[data-gantt-row]").map { |row| row["data-task-id"] }).to eq([ task.id.to_s ])
          expect(task.reload.assignee_ids).to match_array([ member.id, second_member.id, users(:officer).id ])
          expect(task.time_entries.sum(:hours)).to eq(2.5)
     end

     it "keeps an unassigned task on its project board but off all subteam boards" do
          tasks(:wing_test).assign_members([], actor: users(:officer))
          sign_in(users(:officer))
          get tasks_path(filter: { project_id: project.id, subteam_id: wing.id })
          expect(response.parsed_body.css(".task-card")).to be_empty
          expect(response.parsed_body.css(".task-column").size).to eq(3)
          get tasks_path(filter: { project_id: project.id })
          expect(response.parsed_body.css(".task-card").size).to eq(1)
          expect(response.body).to include("Unassigned")
     end

     it "denies a foreign parent and duplicate project name but allows an empty project" do
          sign_in(users(:officer))
          expect { post projects_path, params: { project: { name: "Foreign", team_id: teams(:structures).id } } }.not_to change(Project, :count)
          expect(response).to redirect_to(organization_path)
          get new_project_path(team_id: teams(:structures).id)
          expect(response).to redirect_to(organization_path)
          expect { post projects_path, params: { project: { name: project.name.upcase, team_id: team.id } } }.not_to change(Project, :count)
          expect(response).to have_http_status(:unprocessable_content)
          sign_in(member)
          expect { post projects_path, params: { project: { name: "No", team_id: team.id } } }.not_to change(Project, :count)
     end

     it "keeps a project's parent fixed in the form and preserves the task when viewed" do
          sign_in(users(:chief))
          original = tasks(:wing_test).attributes
          patch project_path(project), params: { project: { team_id: teams(:structures).id, subteam_ids: [] } }
          expect(project.reload.team).to eq(team)
          get project_path(project)
          expect(response.body).to include("Wing load test", "2.5 hours")
          expect(tasks(:wing_test).reload.attributes).to eq(original)
     end

     it "shows every roster person including officers and zero-work members" do
          zero = User.create!(name: "Zero Work", email: "zero@tamu.edu", role: :member, subteam: wing)
          sign_in(users(:officer))
          get subteam_path(wing)
          row = response.parsed_body.at_css("[data-roster-member='#{zero.id}']")
          expect(row.text).to include("No assigned work", "0 hours")
          expect(response.parsed_body.at_css("[data-roster-member='#{users(:officer).id}']")).to be_present
          get subteam_path(second)
          expect(response.body).to include("No members belong to this subteam yet")
     end

     it "atomically transfers a person and updates board membership while preserving task IDs and hours" do
          sign_in(users(:officer))
          assignments = member.assigned_task_ids
          delete subteam_roster_path(wing), params: { user_id: member.id, destination_subteam_id: second.id }
          expect(member.reload.subteam).to eq(second)
          expect(member.assigned_task_ids).to match_array(assignments)
          expect(member.time_entries.sum(:hours)).to eq(2.5)
          expect(Membership.where(user: member).count).to eq(1)
          get subteam_path(second)
          row = response.parsed_body.at_css("[data-roster-member='#{member.id}']")
          expect(row.text).to include("Wing load test", "SAE AERO Design", "Propulsion", "2.5 hours")
          patch subteam_roster_path(wing), params: { user_id: member.id }
          expect(member.reload.subteam).to eq(wing)
     end

     it "refuses removal without a destination and rejects foreign, unknown and revoked people" do
          sign_in(users(:chief))
          delete subteam_roster_path(wing), params: { user_id: member.id }
          expect(flash[:alert]).to include("Choose a destination")
          expect(member.reload.subteam).to eq(wing)
          [ users(:other_member).id, users(:chief).id, 0 ].each do |id|
               patch subteam_roster_path(wing), params: { user_id: id }
               expect(flash[:alert]).to include("Choose an approved member or officer")
          end
          delete subteam_roster_path(second), params: { user_id: member.id, destination_subteam_id: wing.id }
          expect(flash[:alert]).to include("does not belong")
          member.update!(access_revoked_at: Time.current)
          patch subteam_roster_path(second), params: { user_id: member.id }
          expect(flash[:alert]).to include("Choose an approved member or officer")
     end

     it "denies direct roster changes and reads to members and officers of another class" do
          [ users(:member), users(:other_officer) ].each do |person|
               sign_in(person)
               get subteam_path(wing)
               expect(response).to redirect_to(person.member? ? root_path : organization_path)
               expect { patch subteam_roster_path(wing), params: { user_id: member.id } }.not_to change { member.reload.subteam_id }
               expect(flash[:alert]).to include("Access denied")
               delete subteam_roster_path(wing), params: { user_id: member.id, destination_subteam_id: second.id }
               expect(response).to redirect_to(root_path)
          end
     end

     it "scopes roster work and hours to projects and dates without hiding zero-work members" do
          sign_in(users(:chief))
          get subteam_path(wing, filter: { project_id: projects(:archive).id }, from: "2026-10-01", to: "2026-10-02")
          row = response.parsed_body.at_css("[data-roster-member='#{member.id}']")
          expect(row.text).to include("No assigned work", "0 hours")
          get subteam_path(wing, from: "bad-date")
          expect(response.body).to include("Showing hours for all dates")
     end

     it "preserves membership when an existing invalid user cannot be transferred" do
          member.update_columns(name: "")
          sign_in(users(:officer))
          patch subteam_roster_path(second), params: { user_id: member.id }
          expect(flash[:alert]).to include("Name can't be blank")
          expect(member.reload.subteam).to eq(wing)
     end
end
