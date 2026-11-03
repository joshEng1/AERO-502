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

     it "scrolls sideways through one continuous window instead of paging through weeks" do
          sign_in(users(:chief))
          get timeline_path

          scroller = response.parsed_body.at_css("[data-gantt-scroll]")
          expect(scroller.to_h).to include("tabindex" => "0", "role" => "region")
          expect(scroller.at_css("[data-gantt]")).to be_present
          expect(response.parsed_body.at_css("[data-scroll-today]")).to be_present
          expect(response.parsed_body.css("a[data-nav], #weeks")).to be_empty
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

     it "stretches the window to cover every task's dates" do
          sign_in(users(:chief))
          tasks(:spar_check).update!(start_date: Date.new(2026, 8, 5))
          tasks(:wing_test).update!(due_date: Date.new(2026, 12, 16))
          get timeline_path

          gantt = response.parsed_body.at_css("[data-gantt]")
          # Monday Aug 3 through Sunday Dec 20, 2026: 20 weeks.
          expect([ gantt["data-from"], gantt.css("[data-day]").size ]).to eq([ "2026-08-03", 140 ])
          expect(row_for(tasks(:spar_check)).at_css("[data-bar]").to_h).to include("data-offset" => "2", "data-clipped-start" => "false")
          # Sept 28 through Dec 16 is drawn in full: 80 days, starting 56 days in.
          expect(row_for(tasks(:wing_test)).at_css("[data-bar]").to_h).to include("data-offset" => "56", "data-span" => "80")
     end

     it "ignores the old paging parameters" do
          sign_in(users(:chief))
          get timeline_path(from: "2026-10-07", weeks: "4")

          gantt = response.parsed_body.at_css("[data-gantt]")
          expect([ gantt["data-from"], gantt.css("[data-day]").size ]).to eq([ "2026-09-21", 42 ])
     end

     it "limits far-off dates and marks tasks beyond the limits as earlier or later" do
          sign_in(users(:chief))
          tasks(:spar_check).update!(start_date: Date.new(2025, 1, 6), due_date: Date.new(2025, 1, 10))
          tasks(:wing_test).update!(start_date: Date.new(2028, 3, 6), due_date: Date.new(2028, 3, 10))
          get timeline_path

          gantt = response.parsed_body.at_css("[data-gantt]")
          # 26 weeks before Oct 3, 2026 is in the week of Apr 4; 52 weeks after ends Oct 3, 2027.
          expect(gantt["data-from"]).to eq("2026-03-30")
          expect(gantt.css("[data-day]").last.text.squish).to end_with("3")
          expect(row_for(tasks(:spar_check)).at_css("[data-outside]").text).to include("Earlier")
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
