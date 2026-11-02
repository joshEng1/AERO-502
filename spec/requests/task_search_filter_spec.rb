require "rails_helper"

# KAN-21: search and filter tasks by team and subteam.
RSpec.describe "Task search and filters", type: :request do
     def board_titles
          response.parsed_body.css(".task-card h3").map { |title| title.text.squish }
     end

     def filter(**values)
          get tasks_path(filter: { q: "", team_id: "", subteam_id: "" }.merge(values))
     end

     it "searches permitted task titles and descriptions" do
          sign_in(users(:chief))

          filter(q: "LOAD test")
          expect(board_titles).to eq([ "Wing load test" ])
          filter(q: "drawing")
          expect(board_titles).to eq([ "Verify spar dimensions" ])
          filter(q: "100%_")
          expect(board_titles).to be_empty
          expect(response.body).to include("No tasks match your search or filters.")
     end

     it "filters by team and subteam and combines filters with search" do
          sign_in(users(:chief))

          filter(team_id: teams(:structures).id)
          expect(board_titles).to eq([ "Verify spar dimensions" ])
          filter(subteam_id: subteams(:wing).id)
          expect(board_titles).to eq([ "Wing load test" ])
          filter(q: "spar", team_id: teams(:aerodynamics).id)
          expect(board_titles).to be_empty
     end

     it "restores every permitted task when the filters are cleared" do
          sign_in(users(:chief))
          filter(team_id: teams(:structures).id)

          filter
          expect(board_titles).to contain_exactly("Wing load test", "Verify spar dimensions")
     end

     it "never exposes another team's restricted tasks through search" do
          sign_in(users(:member))
          filter(q: "spar")

          expect(board_titles).to be_empty
          expect(response.body).not_to include("Verify spar dimensions")
     end

     it "keeps the chosen filters on My Tasks and the timeline, which return the same tasks" do
          sign_in(users(:chief))
          filter(team_id: teams(:structures).id)

          get tasks_path(view: "mine")
          expect(response.parsed_body.at_css("#filter_team_id option[selected]").text).to eq("Structures")

          get timeline_path
          timeline_titles = response.parsed_body.css("[data-timeline-list] tbody th").map { |cell| cell.text.squish }
          expect(timeline_titles).to eq([ "Verify spar dimensions" ])

          names = response.parsed_body.css(".filter-bar input, .filter-bar select").map { |field| field["name"] }
          expect(names).to include("filter[q]", "filter[project_id]", "filter[team_id]", "filter[subteam_id]")

          get timeline_path(filter: { q: "", team_id: "", subteam_id: "" })
          expect(response.parsed_body.css("[data-timeline-list] tbody th").size).to eq(2)
     end

     it "opens a member's board on their own team and subteam, which they can clear" do
          users(:member).update!(subteam: subteams(:wing))
          sign_in(users(:member))

          get tasks_path
          page = response.parsed_body
          expect(page.at_css("#filter_team_id option[selected]").text).to eq("Aerodynamics")
          expect(page.at_css("#filter_subteam_id option[selected]").text).to eq("Aerodynamics · Wing Analysis")
          expect(board_titles).to eq([ "Wing load test" ])

          filter
          expect(response.parsed_body.at_css("#filter_team_id option[selected]")).to be_nil
          get tasks_path
          expect(response.parsed_body.at_css("#filter_team_id option[selected]")).to be_nil
     end

     it "labels every filter control" do
          sign_in(users(:officer))
          get tasks_path

          controls = response.parsed_body.css(".filter-bar input[type=search], .filter-bar select")
          expect(controls.size).to eq(7)
          controls.each do |control|
               expect(response.parsed_body.at_css("label[for='#{control["id"]}']")).to be_present
          end
     end
end
