require "rails_helper"

RSpec.describe "Board creation and prerequisites", type: :request do
     let(:project) { projects(:aero) }
     let(:task) { tasks(:wing_test) }
     let(:officer) { users(:officer) }

     def prerequisite(title = "Build fixture")
          Task.create!(title: title, project: project, creator: officer, estimated_hours: 1,
                       start_date: Date.current, due_date: Date.current + 2)
     end

     it "keeps empty columns and starts creation in each chosen column with the project prefilled" do
          sign_in(officer)
          filter = { project_id: projects(:archive).id, subteam_id: subteams(:wing).id }
          get tasks_path(filter: filter)
          page = response.parsed_body
          expect(page.css(".task-column").size).to eq(3)
          links = page.css('.task-column a').select { |a| a.text == "Add task" }.map { |a| a["href"] }
          expect(links.size).to eq(3)
          links.zip(Task.statuses.keys).each do |url, status|
               get url
               expect(response.parsed_body.at_css('#task_status option[selected]')["value"]).to eq(status)
               expect(response.parsed_body.at_css('#task_project_id option[selected]')["value"]).to eq(projects(:archive).id.to_s)
               post tasks_path, params: { return_to_board: "1", filter: filter, task: {
                    title: "New #{status}", project_id: projects(:archive).id, status: status,
                    due_date: Date.current, estimated_hours: 2, assignee_ids: [ users(:member).id ]
               } }
               expect(response).to redirect_to(tasks_path(filter: filter))
               follow_redirect!
               expect(response.parsed_body.at_css("##{status}-heading").ancestors("section").first.text).to include("New #{status}")
          end
     end

     it "asks for a project when several are selected and retains entered values and filters on errors and cancel" do
          sign_in(officer)
          filter = { project_ids: [ project.id, projects(:archive).id ], subteam_id: subteams(:wing).id }
          get new_task_path(filter: filter, return_to_board: "1", status: "in_progress")
          expect(response.parsed_body.at_css('#task_project_id option[selected]')).to be_nil
          expect(response.body).to include("Several projects are selected")
          post tasks_path, params: { return_to_board: "1", filter: filter, task: {
               title: "Keep this title", project_id: project.id, status: "in_progress", due_date: "",
               estimated_hours: 2, assignee_ids: [ users(:member).id ]
          } }
          expect(response).to have_http_status(:unprocessable_content)
          page = response.parsed_body
          expect(page.at_css('#task_title')["value"]).to eq("Keep this title")
          expect(page.css('#task_assignee_ids option[selected]').map { |o| o["value"].to_i }).to eq([ users(:member).id ])
          expect(page.at_css('#task_status option[selected]')["value"]).to eq("in_progress")
          cancel = page.css('a').find { |a| a.text == "Cancel" }
          get cancel["href"]
          expect(response.parsed_body.at_css('#filter_subteam_id option[selected]')["value"]).to eq(subteams(:wing).id.to_s)
     end

     it "offers the project board after an unassigned save and does not invent subteam ownership" do
          sign_in(officer)
          post tasks_path, params: { return_to_board: "1", filter: { project_id: project.id, subteam_id: subteams(:wing).id }, task: {
               title: "Unassigned planning", project_id: project.id, due_date: Date.current, estimated_hours: 0,
               assignee_ids: [ "" ]
          } }
          follow_redirect!
          expect(response.body).to include("This task has no assignees")
          expect(response.parsed_body.css('.task-card').map(&:text).join).not_to include("Unassigned planning")
          get response.parsed_body.css('a').find { |a| a.text == "Open its project board" }["href"]
          expect(response.body).to include("Unassigned planning")
          get new_task_path(status: "unknown", filter: { q: "" })
          expect(response.parsed_body.at_css('#task_status option[selected]')["value"]).to eq("backlog")
     end

     it "keeps one optional primary contact among active assignees and clears it on removal" do
          sign_in(officer)
          patch task_path(task), params: { task: { assignee_ids: [ users(:member).id, officer.id ], primary_contact_id: officer.id } }
          expect(task.reload.primary_contact).to eq(officer)
          patch task_path(task), params: { task: { primary_contact_id: users(:other_member).id } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(task.reload.primary_contact).to eq(officer)
          patch task_path(task), params: { task: { assignee_ids: [ users(:member).id ] } }
          expect(task.reload.primary_contact).to be_nil
          expect(task.task_assignments.find_by(user: officer).is_primary_contact).to be(false)
     end

     it "shows outstanding prerequisites with their owners and clears only the derived blocked state" do
          first, second = prerequisite, prerequisite("Inspect fixture")
          first.assign_members([ officer.id ], actor: officer)
          sign_in(officer)
          patch task_path(task), params: { task: { prerequisite_ids: [ first.id, second.id ] } }
          expect(task.reload).to be_blocked
          get task_path(task)
          expect(response.parsed_body.at_css('[data-prerequisites]').text).to include("Build fixture", "Inspect fixture", "Olivia Officer", "Backlog")
          dates = [ task.start_date, task.due_date ]
          patch task_path(first), params: { task: { status: "completed" } }
          expect(task.reload).to be_blocked
          patch task_path(second), params: { task: { status: "completed" } }
          expect(task.reload).not_to be_blocked
          expect(task).to be_backlog
          expect([ task.start_date, task.due_date ]).to eq(dates)
          patch task_path(task), params: { task: { prerequisite_ids: [ "" ] } }
          expect(task.reload.prerequisites).to be_empty
     end

     it "rejects self-links, circular chains, foreign teams and unknown tasks without partial edits" do
          first, second = prerequisite, prerequisite("Inspect fixture")
          sign_in(officer)
          patch task_path(task), params: { task: { prerequisite_ids: [ first.id ] } }
          patch task_path(first), params: { task: { prerequisite_ids: [ second.id ] } }
          patch task_path(second), params: { task: { prerequisite_ids: [ task.id ] } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(second.reload.prerequisites).to be_empty
          [ task.id, tasks(:spar_check).id, 0 ].each do |id|
               patch task_path(task), params: { task: { title: "Invalid edit", prerequisite_ids: [ id ] } }
               expect(response).to have_http_status(:unprocessable_content)
               expect(task.reload.title).to eq("Wing load test")
               expect(task.prerequisite_ids).to eq([ first.id ])
          end
     end

     it "denies member dependency edits even though the member can update task status" do
          first = prerequisite
          sign_in(users(:member))
          patch task_path(task), params: { task: { status: "completed", prerequisite_ids: [ first.id ] } }
          expect(response).to redirect_to(root_path)
          expect(task.reload.prerequisites).to be_empty
          expect(task).to be_backlog
          sign_in(users(:other_officer))
          patch task_path(task), params: { task: { prerequisite_ids: [ first.id ] } }
          expect(response).to redirect_to(root_path)
     end

     it "does not reveal unassigned prerequisite task details to a member" do
          first = prerequisite("Leader-only prerequisite")
          task.replace_prerequisites([ first.id ], actor: officer)
          sign_in(users(:member))
          get task_path(task)
          expect(response.body).to include("Blocked by unfinished prerequisite work")
          expect(response.body).not_to include(first.title)
          get task_path(first)
          expect(response).to redirect_to(root_path)
     end

     it "excludes archived projects from new task choices even when an old filter names one" do
          project.update!(archived_at: Time.current)
          sign_in(officer)
          get new_task_path(filter: { project_id: project.id })
          expect(response.parsed_body.css('#task_project_id option').map { |option| option["value"] }).not_to include(project.id.to_s)
          post tasks_path, params: { task: { title: "Archived target", project_id: project.id, due_date: Date.current, estimated_hours: 0 } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("must be active and belong to an active class")
          expect(Task.find_by(title: "Archived target")).to be_nil
          patch task_path(task), params: { task: { title: "Retained archived task" } }
          expect(task.reload.title).to eq("Retained archived task")
          project.update!(archived_at: nil)
          project.team.update!(archived_at: Time.current)
          post tasks_path, params: { task: { title: "Archived class target", project_id: project.id, due_date: Date.current, estimated_hours: 0 } }
          expect(response).to have_http_status(:unprocessable_content)
     end

     it "retains revoked assignees on an unrelated edit but prevents new revoked assignments" do
          person = users(:member)
          person.update!(access_revoked_at: Time.current)
          sign_in(officer)
          get edit_task_path(task)
          expect(response.parsed_body.css('#task_assignee_ids option[selected]').map { |option| option["value"].to_i }).to include(person.id)
          patch task_path(task), params: { task: { title: "Instructions corrected", assignee_ids: [ person.id ] } }
          expect(response).to redirect_to(task_path(task))
          expect(task.reload.assignee_ids).to include(person.id)
          expect(task.task_assignments.count).to eq(1)
          new_task = prerequisite
          patch task_path(new_task), params: { task: { assignee_ids: [ person.id ] } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(new_task.reload.assignee_ids).to be_empty
     end
end
