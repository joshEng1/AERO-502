require "rails_helper"

# KAN-37 / scope S04 / US-8: the task form's searchable member selector.
# app/javascript/member_selector.js builds the picker from the checkbox list
# rendered here, so these specs cover the eligible members it is given and the
# assignments the server accepts.
RSpec.describe "Searchable member selector", type: :request do
     def sign_in_as(user)
          post login_path, params: { email: users(user).email, password: "password" }
     end

     def member_options
          response.parsed_body.css("[data-member-selector] label[data-member-name]").to_h do |label|
               [ label["data-member-name"], label["data-team-id"] ]
          end
     end

     def project_team_ids
          response.parsed_body.css("select[name='task[project_id]'] option[data-team-id]").to_h do |option|
               [ option.text, option["data-team-id"] ]
          end
     end

     it "gives an officer only their own team's members to search" do
          sign_in_as(:officer)
          get new_task_path

          expect(response).to have_http_status(:ok)
          expect(member_options).to eq("Morgan Member" => teams(:aerodynamics).id.to_s)
     end

     it "tags every member and project with its team so the picker can follow the chosen project" do
          sign_in_as(:chief)
          get new_task_path

          expect(member_options).to eq(
               "Bailey Member" => teams(:structures).id.to_s,
               "Morgan Member" => teams(:aerodynamics).id.to_s
          )
          expect(member_options.keys).not_to include("Casey Chief")
          expect(project_team_ids).to include(
               projects(:aero).full_name => teams(:aerodynamics).id.to_s,
               projects(:airframe_build).full_name => teams(:structures).id.to_s
          )
     end

     it "keeps the members already assigned selected when editing" do
          sign_in_as(:officer)
          get edit_task_path(tasks(:wing_test))

          checked = response.parsed_body.css("[data-member-selector] input[type=checkbox][checked]").map { |box| box["value"] }
          expect(checked).to eq([ users(:member).id.to_s ])
     end

     it "unassigns only the member removed from the selector" do
          sam = User.create!(name: "Sam Lee", email: "sam.lee@example.test", password: "password",
                             role: :member, team: teams(:aerodynamics))
          tasks(:wing_test).assignees << sam
          sign_in_as(:officer)

          patch task_path(tasks(:wing_test)), params: { task: { assignee_ids: [ "", users(:member).id ] } }

          expect(response).to redirect_to(task_path(tasks(:wing_test)))
          expect(tasks(:wing_test).reload.assignees).to eq([ users(:member) ])
     end

     it "refuses a Chief Engineer as an assignee sent in a direct request" do
          sign_in_as(:chief)

          patch task_path(tasks(:wing_test)), params: {
               task: { title: "Chief assigned", assignee_ids: [ users(:member).id, users(:chief).id ] }
          }

          expect(response).to have_http_status(:unprocessable_content)
          expect(tasks(:wing_test).reload.title).to eq("Wing load test")
          expect(tasks(:wing_test).assignees).to eq([ users(:member) ])
     end

     it "loads the selector script on the task form" do
          sign_in_as(:officer)
          get new_task_path

          expect(response.body).to include("member_selector")
          expect(response.parsed_body.at_css("[data-member-selector] [data-member-options]")).to be_present
     end
end
