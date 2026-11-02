require "rails_helper"

RSpec.describe "Delivered task card stories", type: :request do
     def sign_in_as_officer
          post login_path, params: { email: users(:officer).email, password: "password" }
     end

     def task_attributes(overrides = {})
          {
               title: "Inspect new wing bracket",
               description: "Upload the signed inspection sheet.",
               instructions: "Use revision C and photograph both faces.",
               reference_links_text: "https://example.com/bracket-plan",
               start_date: "2026-10-05",
               due_date: "2026-10-12",
               estimated_hours: "6.25",
               project_id: projects(:aero).id,
               assignee_ids: [ users(:member).id ]
          }.merge(overrides)
     end

     it "creates a complete task card and renders its saved fields on detail and edit pages" do
          sign_in_as_officer

          expect do
               post tasks_path, params: { task: task_attributes }
          end.to change(Task, :count).by(1)

          task = Task.order(:id).last
          expect(response).to redirect_to(task_path(task))
          expect(task.attributes.symbolize_keys).to include(
               title: "Inspect new wing bracket",
               description: "Upload the signed inspection sheet.",
               instructions: "Use revision C and photograph both faces.\n\nReference links:\nhttps://example.com/bracket-plan",
               start_date: Date.new(2026, 10, 5),
               due_date: Date.new(2026, 10, 12),
               estimated_hours: 6.25,
               status: "backlog",
               project_id: projects(:aero).id,
               creator_id: users(:officer).id
          )
          expect(task.assignee_ids).to eq([ users(:member).id ])
          expect(task.reference_urls).to eq([ "https://example.com/bracket-plan" ])

          get task_path(task)
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Inspect new wing bracket", "Upload the signed inspection sheet.",
                                           "Use revision C and photograph both faces.", "Morgan Member", "6.25h")
          expect(response.parsed_body.at_css('a[href="https://example.com/bracket-plan"]')).to be_present

          get edit_task_path(task)
          expect(response).to have_http_status(:ok)
          form = response.parsed_body
          expect(form.at_css('input[name="task[title]"]')["value"]).to eq("Inspect new wing bracket")
          expect(form.at_css('textarea[name="task[description]"]').text).to eq("Upload the signed inspection sheet.")
          expect(form.at_css('textarea[name="task[instructions]"]').text).to eq("Use revision C and photograph both faces.")
          expect(form.at_css('textarea[name="task[reference_links_text]"]').text.strip).to eq("https://example.com/bracket-plan")
          expect(form.at_css('input[name="task[due_date]"]')["value"]).to eq("2026-10-12")
          expect(form.at_css('input[name="task[estimated_hours]"]')["value"]).to eq("6.25")
          expect(form.at_css('select[name="task[status]"] option[selected]')["value"]).to eq("backlog")
          expect(form.at_css('select[name="task[project_id]"] option[selected]')["value"]).to eq(projects(:aero).id.to_s)
     end

     it "saves an edited estimate and rejects negative and nonnumeric estimates" do
          sign_in_as_officer
          post tasks_path, params: { task: task_attributes }
          task = Task.order(:id).last

          patch task_path(task), params: { task: { estimated_hours: "7.50", assignee_ids: [ users(:member).id ] } }
          expect(response).to redirect_to(task_path(task))
          expect(task.reload.estimated_hours).to eq(7.5)
          get task_path(task)
          expect(response.body).to include("7.5h")

          [ "-1", "not-a-number" ].each do |invalid_estimate|
               patch task_path(task), params: { task: { estimated_hours: invalid_estimate, assignee_ids: [ users(:member).id ] } }
               expect(response).to have_http_status(:unprocessable_content)
               expect(task.reload.estimated_hours).to eq(7.5)
          end

          [ "-1", "not-a-number" ].each do |invalid_estimate|
               expect do
                    post tasks_path, params: { task: task_attributes(estimated_hours: invalid_estimate) }
               end.not_to change(Task, :count)
               expect(response).to have_http_status(:unprocessable_content)
          end
     end

     it "assigns multiple members once each and removes a member when edited" do
          second_member = User.create!(name: "Taylor Member", email: "taylor@example.test", password: "password",
                                       role: :member, subteam: subteams(:wing))
          sign_in_as_officer

          post tasks_path, params: {
               task: task_attributes(assignee_ids: [ users(:member).id, second_member.id, second_member.id ])
          }
          task = Task.order(:id).last
          expect(response).to redirect_to(task_path(task))
          expect(task.task_assignments.count).to eq(2)
          expect(task.assignee_ids).to match_array([ users(:member).id, second_member.id ])

          get task_path(task)
          expect(response.body).to include("Morgan Member", "Taylor Member")
          get edit_task_path(task)
          checked_ids = response.parsed_body.css('select[name="task[assignee_ids][]"] option[selected]').map { |input| input["value"].to_i }
          expect(checked_ids).to match_array([ users(:member).id, second_member.id ])

          patch task_path(task), params: { task: { assignee_ids: [ "", second_member.id ] } }
          expect(response).to redirect_to(task_path(task))
          expect(task.reload.assignee_ids).to eq([ second_member.id ])
          expect(task.task_assignments.count).to eq(2)
          expect(task.active_assignments.count).to eq(1)
          get task_path(task)
          assigned = response.parsed_body.css(".detail-list div").find { |row| row.at_css("dt").text == "Assigned members" }
          expect(assigned.at_css("dd").text).to eq("Taylor Member")
     end
end
