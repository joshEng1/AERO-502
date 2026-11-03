require "rails_helper"

# KAN-10: leaders create task cards with deliverables, instructions, links,
# start and due dates, and estimated hours.
RSpec.describe "Task card creation", type: :request do
     def valid_task(overrides = {})
          {
               title: "Machine wing ribs",
               description: "Twelve finished ribs.",
               instructions: "Use the CNC template.",
               reference_links_text: "https://example.com/ribs\nhttps://example.com/cnc",
               start_date: Date.current.iso8601,
               due_date: (Date.current + 7).iso8601,
               estimated_hours: "8",
               project_id: projects(:aero).id,
               team_id: teams(:aerodynamics).id,
               subteam_id: subteams(:wing).id
          }.merge(overrides)
     end

     it "defaults the start date to today and marks only the required fields as required" do
          sign_in(users(:officer))
          get new_task_path
          form = response.parsed_body

          expect(form.at_css('input[name="task[start_date]"]')["value"]).to eq(Date.current.iso8601)
          %w[title due_date estimated_hours].each do |field|
               expect(form.at_css("[name='task[#{field}]']")["required"]).not_to be_nil
          end
          %w[description instructions reference_links_text].each do |field|
               expect(form.at_css("[name='task[#{field}]']")["required"]).to be_nil
          end
     end

     it "shows an error next to each missing required field and saves nothing" do
          sign_in(users(:officer))

          expect do
               post tasks_path, params: { task: valid_task(title: "", due_date: "", estimated_hours: "") }
          end.not_to change(Task, :count)

          expect(response).to have_http_status(:unprocessable_content)
          page = response.parsed_body
          expect(page.at_css("#task_title_error").text).to include("can't be blank")
          expect(page.at_css("#task_due_date_error").text).to include("can't be blank")
          expect(page.at_css("#task_estimated_hours_error").text).to include("is not a number")
          expect(page.at_css('[name="task[title]"]')["aria-describedby"]).to eq("task_title_error")
     end

     it "rejects a due date earlier than the start date with a message next to the due date" do
          sign_in(users(:officer))

          expect do
               post tasks_path, params: { task: valid_task(due_date: (Date.current - 1).iso8601) }
          end.not_to change(Task, :count)

          expect(response.parsed_body.at_css("#task_due_date_error").text)
               .to include("must be on or after the start date")
     end

     it "asks for a full web address when a reference link is invalid" do
          sign_in(users(:officer))

          expect do
               post tasks_path, params: { task: valid_task(reference_links_text: "https://ok.example.com\nnot a link") }
          end.not_to change(Task, :count)

          expect(response.parsed_body.at_css("#task_reference_links_text_error").text)
               .to include("must each be a full web address starting with http:// or https://")
     end

     it "saves the chosen initial status, keeps reference links in instructions, and shows every detail" do
          sign_in(users(:officer))

          expect do
               post tasks_path, params: { task: valid_task(status: "completed") }
          end.to change(Task, :count).by(1)

          task = Task.order(:id).last
          expect(task).to be_completed
          expect(task.reference_urls).to eq([ "https://example.com/ribs", "https://example.com/cnc" ])
          follow_redirect!
          expect(response.body).to include("Task was created successfully.")
          page = response.parsed_body
          expect(page.css("a[target='_blank']").map { |link| link["href"] })
               .to include("https://example.com/ribs", "https://example.com/cnc")
          expect(response.body).to include(I18n.l(Date.current, format: :long))
          expect(response.body).to include("Twelve finished ribs.", "Use the CNC template.")

          get tasks_path
          backlog = response.parsed_body.at_css("#completed-heading").ancestors("section").first
          expect(backlog.text).to include("Machine wing ribs")
     end

     it "accepts optional fields left blank and a due date equal to the start date" do
          sign_in(users(:officer))

          expect do
               post tasks_path, params: {
                    task: valid_task(description: "", instructions: "", reference_links_text: "",
                                     due_date: Date.current.iso8601, estimated_hours: "0")
               }
          end.to change(Task, :count).by(1)
     end

     it "lets the Chief Engineer create a task card for any team" do
          sign_in(users(:chief))

          expect do
               post tasks_path, params: {
                    task: valid_task(project_id: projects(:airframe_build).id, subteam_id: subteams(:airframe).id)
               }
          end.to change(Task, :count).by(1)
          expect(Task.order(:id).last.team).to eq(teams(:structures))
     end

     it "replaces the saved links when a leader edits them" do
          sign_in(users(:officer))
          patch task_path(tasks(:wing_test)), params: { task: { reference_links_text: "https://example.com/new" } }

          expect(tasks(:wing_test).reload.reference_urls).to eq([ "https://example.com/new" ])
     end

     it "hides the Create Task option from members and refuses direct creation" do
          sign_in(users(:member))
          get tasks_path
          expect(response.body).not_to include("New Task")

          expect do
               post tasks_path, params: { task: valid_task }
          end.not_to change(Task, :count)
          expect(response).to redirect_to(root_path)
     end
end
