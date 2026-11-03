require "rails_helper"

# KAN-29 (board shows counts and overdue work instead of a separate dashboard)
# and KAN-11 / scope S07 (status counts, assignments, overdue tasks and member
# hours for a date range, as a chart and a table) on the task board.
RSpec.describe "Board summary and hours", type: :request do
     around { |example| travel_to(Date.new(2026, 10, 3)) { example.run } }

     before do
          TimeEntry.create!(task: tasks(:wing_test), user: users(:member), hours: 1, worked_on: Date.new(2026, 9, 30))
     end

     def column_counts
          response.parsed_body.css(".column-heading").to_h { |heading| [ heading.at_css("h2")["id"].delete_suffix("-heading"), heading.at_css("span").text ] }
     end

     def card_for(task)
          response.parsed_body.css(".task-card").find { |card| card.text.include?(task.title) }
     end

     def hour_rows
          response.parsed_body.css("[data-member-hours] tbody tr").to_h do |row|
               cells = row.css("th, td").map { |cell| cell.text.squish }
               [ cells.first, cells.drop(1) ]
          end
     end

     def filter(**values)
          { filter: { q: "", project_id: "", team_id: "", subteam_id: "" }.merge(values) }
     end

     it "AC1/AC3: shows each column's count for the current filters" do
          sign_in(users(:chief))
          get tasks_path(filter)
          expect(column_counts).to eq("backlog" => "1", "in_progress" => "1", "completed" => "0")

          get tasks_path(filter(team_id: teams(:structures).id))
          expect(column_counts).to eq("backlog" => "0", "in_progress" => "1", "completed" => "0")
     end

     it "AC2: labels unfinished tasks past their due date as Overdue automatically" do
          sign_in(users(:chief))
          get tasks_path(filter)

          expect(card_for(tasks(:spar_check)).at_css(".overdue-label").text).to eq("Overdue")
          expect(card_for(tasks(:wing_test)).at_css(".overdue-label")).to be_nil

          tasks(:spar_check).update!(status: :completed, acting_user: users(:chief))
          get tasks_path
          expect(card_for(tasks(:spar_check)).at_css(".overdue-label")).to be_nil
     end

     it "AC5: keeps all three columns, including Completed, visible" do
          sign_in(users(:chief))
          get tasks_path

          expect(response.parsed_body.css(".task-column h2").map(&:text)).to eq([ "Backlog", "In progress", "Completed" ])
     end

     it "sums up overdue work and hours for leaders above the board" do
          sign_in(users(:chief))
          get tasks_path(filter)

          expect(response.parsed_body.at_css("[data-board-summary]").text.squish)
               .to include("1 overdue", "5h actual of 14h estimated")
     end

     it "AC4: shows the member hour summary under the board as a table and a matching chart" do
          sign_in(users(:chief))
          get tasks_path(filter.merge(from: "2026-09-28", to: "2026-09-30"))

          expect(hour_rows).to include(
               "Morgan Member" => [ "10 hours", "1 hour", "9 hours under estimate" ],
               "Bailey Member" => [ "4 hours", "0 hours", "4 hours under estimate" ],
               "Project total" => [ "14 hours", "1 hour", "13 hours under estimate" ]
          )
          chart = response.parsed_body.css("[data-member-chart] [data-member]").to_h { |bar| [ bar["data-member"], bar["data-actual"] ] }
          expect(chart).to eq("Bailey Member" => "0.0", "Morgan Member" => "1.0", "Olivia Officer" => "0.0", "Owen Officer" => "0.0")
     end

     it "includes both endpoint dates and labels shared estimates without double counting them" do
          second = User.create!(name: "Sam Second", email: "sam@example.test", password: "password", role: :member, subteam: subteams(:wing))
          tasks(:wing_test).assign_members(tasks(:wing_test).assignee_ids + [ second.id ], actor: users(:officer))
          sign_in(users(:chief))
          get tasks_path(filter.merge(from: "2026-09-27", to: "2026-09-30"))

          expect(response.body).to include("Assigned-task estimate (shared)")
          expect(hour_rows.transform_values { |cells| cells.first(2) }).to include(
               "Morgan Member" => [ "10 hours", "3.5 hours" ], "Sam Second" => [ "10 hours", "0 hours" ],
               "Project total" => [ "14 hours", "5 hours" ]
          )
     end

     it "rejects a reversed or unreadable date range and shows all hours instead" do
          sign_in(users(:chief))

          get tasks_path(from: "2026-09-30", to: "2026-09-01")
          expect(response.body).to include("End date must be on or after the start date")
          get tasks_path(from: "not-a-date")
          expect(response.body).to include("Start date is not a valid date")
          expect(hour_rows["Project total"].first(2)).to eq([ "14 hours", "5 hours" ])
     end

     it "narrows the board and hours to a selected project" do
          sign_in(users(:chief))
          get tasks_path(filter(project_id: projects(:aero).id))

          expect(response.parsed_body.css(".task-card h3").map(&:text)).to eq([ "Wing load test" ])
          expect(hour_rows.keys).to eq([ "Morgan Member", "Olivia Officer", "Project total" ])
          expect(response.parsed_body.at_css("#filter_project_id option[selected]").text)
               .to eq("Aerodynamics · SAE AERO Design")
     end

     it "keeps the hours date range when filters change, and the filters when dates change" do
          sign_in(users(:chief))
          get tasks_path(filter(team_id: teams(:aerodynamics).id).merge(from: "2026-09-28", to: "2026-09-30"))

          kept = response.parsed_body.css("form.filter-bar input[type=hidden]").to_h { |field| [ field["name"], field["value"] ] }
          expect(kept).to include("from" => "2026-09-28", "to" => "2026-09-30")
          range = response.parsed_body.at_css("[data-member-hours] form[data-hours-range]")
          expect(range["action"]).to eq(tasks_path(anchor: "hours"))
          expect(response.parsed_body.at_css("#filter_team_id option[selected]").text).to eq("Aerodynamics")
     end

     it "shows an officer only their own team" do
          sign_in(users(:officer))
          get tasks_path

          expect(hour_rows.keys).to eq([ "Morgan Member", "Olivia Officer", "Project total" ])
          expect(response.body).not_to include("Verify spar dimensions")
     end

     it "shows members no hours summary and no leader summary" do
          sign_in(users(:member))
          get tasks_path

          expect(response.parsed_body.at_css("[data-member-hours]")).to be_nil
          expect(response.parsed_body.at_css("[data-board-summary]")).to be_nil
     end

     it "shows the hours summary on the board view only, not My Tasks" do
          sign_in(users(:chief))
          get tasks_path(view: "mine")

          expect(response.parsed_body.at_css("[data-member-hours]")).to be_nil
     end

     it "shows new values after a status or hours change when the leader refreshes" do
          sign_in(users(:chief))
          get tasks_path(filter)
          tasks(:wing_test).update!(status: :completed, acting_user: users(:chief))
          TimeEntry.create!(task: tasks(:wing_test), user: users(:member), hours: 2, worked_on: Date.new(2026, 10, 1))

          get tasks_path
          expect(column_counts["completed"]).to eq("1")
          expect(hour_rows["Morgan Member"].first(2)).to eq([ "10 hours", "5.5 hours" ])
     end

     it "removes Progress from the menu and sends old Progress and Dashboard links to the board's hours" do
          sign_in(users(:chief))
          get tasks_path
          links = response.parsed_body.css("nav[aria-label='Primary navigation'] a").map { |link| link.text.squish }
          expect(links).to eq([ "Tasks", "My Tasks", "Timeline", "Teams", "People", "Help", "New Task" ])

          get "/progress?from=2026-09-28"
          expect(response).to redirect_to("/tasks?from=2026-09-28#hours")
          get "/dashboard"
          expect(response).to redirect_to("/tasks#hours")
     end
end
