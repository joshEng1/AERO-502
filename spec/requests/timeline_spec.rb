require "rails_helper"

# KAN-23 / scope S11: leaders see task dates on a Gantt-style timeline.
RSpec.describe "Task timeline", type: :request do
     around { |example| travel_to(Date.new(2026, 10, 3)) { example.run } }

     def row_for(task)
          response.parsed_body.at_css("[data-gantt-row][data-task-id='#{task.id}']")
     end

     it "draws each task as a bar from its start date to its due date, grouped by team and subteam" do
          sign_in(users(:chief))
          get timeline_path

          # The default window starts on the Monday of the previous week: Sept 21, 2026.
          expect(response.parsed_body.at_css("[data-gantt]")["data-from"]).to eq("2026-09-21")
          bar = row_for(tasks(:wing_test)).at_css("[data-bar]")
          expect(bar.to_h).to include("data-offset" => "7", "data-span" => "8", "data-status" => "backlog")

          team = response.parsed_body.at_css("[data-gantt-team='#{teams(:aerodynamics).id}']")
          subteam = team.at_css("[data-gantt-subteam='#{subteams(:wing).id}']")
          expect(team.at_css(".gantt-team-label").text).to include("Aerodynamics")
          expect(subteam.at_css(".gantt-subteam-label").text).to include("Wing Analysis")
          expect(subteam.css("[data-gantt-row]").map { |row| row["data-task-id"] }).to eq([ tasks(:wing_test).id.to_s ])
     end

     it "offers 4, 6, 8 or 12 week windows and defaults to 6 weeks" do
          sign_in(users(:chief))
          get timeline_path

          options = response.parsed_body.css("#weeks option").map { |option| option.text }
          expect(options).to eq([ "4 weeks", "6 weeks", "8 weeks", "12 weeks" ])
          expect(response.parsed_body.at_css("#weeks option[selected]").text).to eq("6 weeks")
     end

     it "shows a day axis with week headings and a line for today" do
          sign_in(users(:chief))
          get timeline_path

          gantt = response.parsed_body.at_css("[data-gantt]")
          expect(gantt.css("[data-day]").size).to eq(42)
          expect(gantt.css("[data-week]").map { |week| week.text.squish }.first(2)).to eq([ "Sep 21", "Sep 28" ])
          expect(gantt.at_css("[data-today]")["data-offset"]).to eq("12")
     end

     it "highlights unfinished tasks past their due date as overdue, in the chart and the text list" do
          sign_in(users(:chief))
          get timeline_path

          expect(row_for(tasks(:spar_check)).at_css("[data-bar]")["data-overdue"]).to eq("true")
          expect(row_for(tasks(:wing_test)).at_css("[data-bar]")["data-overdue"]).to eq("false")
          list = response.parsed_body.css("[data-timeline-list] tbody tr").map { |row| row.text.squish }
          expect(list).to include(a_string_including("Verify spar dimensions", "September 24, 2026", "October 01, 2026", "Overdue"))
     end

     it "lists the same dates in a text table for every task shown" do
          sign_in(users(:chief))
          get timeline_path

          list = response.parsed_body.css("[data-timeline-list] tbody tr").map { |row| row.css("th, td").map { |cell| cell.text.squish } }
          expect(list).to include([ "Wing load test", "Aerodynamics · Wing Analysis", "September 28, 2026", "October 05, 2026", "Backlog" ])
     end

     it "follows the team and subteam filters" do
          sign_in(users(:chief))
          get timeline_path(filter: { team_id: teams(:structures).id })

          expect(response.parsed_body.css("[data-gantt-row]").map { |row| row["data-task-id"] })
               .to eq([ tasks(:spar_check).id.to_s ])
     end

     it "reflects changed dates when the leader refreshes" do
          sign_in(users(:chief))
          tasks(:wing_test).update!(due_date: Date.new(2026, 10, 9))
          get timeline_path

          expect(row_for(tasks(:wing_test)).at_css("[data-bar]")["data-span"]).to eq("12")
     end

     it "moves between date windows and marks tasks that fall outside the window" do
          sign_in(users(:chief))
          get timeline_path(from: "2026-10-07", weeks: "4")

          gantt = response.parsed_body.at_css("[data-gantt]")
          expect(gantt["data-from"]).to eq("2026-10-05")
          expect(gantt.css("[data-day]").size).to eq(28)
          expect(row_for(tasks(:spar_check)).at_css("[data-bar]")).to be_nil
          expect(row_for(tasks(:spar_check)).at_css("[data-outside]").text).to include("Earlier")
          expect(response.parsed_body.at_css("a[data-nav='previous']")["href"]).to include("from=2026-09-07", "weeks=4")

          bar = row_for(tasks(:wing_test)).at_css("[data-bar]")
          expect(bar.to_h).to include("data-offset" => "0", "data-span" => "1", "data-clipped-start" => "true")
     end

     it "falls back to the default window for unreadable dates or sizes" do
          sign_in(users(:chief))
          get timeline_path(from: "soon", weeks: "99")

          gantt = response.parsed_body.at_css("[data-gantt]")
          expect([ gantt["data-from"], gantt.css("[data-day]").size ]).to eq([ "2026-09-21", 42 ])
     end

     it "marks tasks that start after the window as later" do
          sign_in(users(:chief))
          get timeline_path(from: "2026-08-31", weeks: "4")

          expect(row_for(tasks(:wing_test)).at_css("[data-outside]").text).to include("Later")
     end

     it "shows an officer only their own team and hides the timeline from members" do
          sign_in(users(:officer))
          get timeline_path
          expect(response.parsed_body.css("[data-gantt-row]").map { |row| row["data-task-id"] })
               .to eq([ tasks(:wing_test).id.to_s ])

          sign_in(users(:member))
          get tasks_path
          expect(response.parsed_body.at_css("nav a[href='#{timeline_path}']")).to be_nil
          get timeline_path
          expect(response).to redirect_to(tasks_path)
          expect(flash[:alert]).to eq("Access denied. The timeline is available to team officers and the Chief Engineer.")
     end

     it "explains an empty timeline" do
          sign_in(users(:chief))
          get timeline_path(filter: { q: "no such task" })

          expect(response.body).to include("No tasks match these filters.")
     end
end
