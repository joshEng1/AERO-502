require "rails_helper"
require "csv"

RSpec.describe "Filtered CSV reports", type: :request do
     let(:team) { teams(:aerodynamics) }
     let(:project) { projects(:aero) }
     let(:subteam) { Subteam.create!(team: team, name: "Report Subteam") }
     let(:day_one) { Date.current - 2 }
     let(:day_two) { Date.current - 1 }
     let(:filter) { { q: "", team_id: team.id, subteam_id: subteam.id, project_id: project.id } }

     def csv_rows
          CSV.parse(response.body.dup.force_encoding("UTF-8").delete_prefix("\uFEFF"), headers: true)
     end

     before do
          @e, @f, @g = %w[E F G].map do |name|
               User.create!(name: "Member #{name}", email: "report.#{name.downcase}@tamu.edu", role: :member, team: team, subteam: subteam)
          end
          @shared = Task.create!(title: "Shared report task", project: project, creator: users(:chief), estimated_hours: 10,
                                 start_date: day_one, due_date: day_two)
          @shared.assign_members([ @e.id, @f.id ], actor: users(:chief))
          TimeEntry.create!(task: @shared, user: @e, hours: 2.5, worked_on: day_one)
          TimeEntry.create!(task: @shared, user: @e, hours: 2.5, worked_on: day_two)
          TimeEntry.create!(task: @shared, user: @f, hours: 3, worked_on: day_two)
          @formula = Task.create!(title: "=SUM(1,1)", project: project, creator: users(:chief), estimated_hours: 0,
                                  start_date: day_one, due_date: day_two)
          @formula.assign_members([ @f.id ], actor: users(:chief))
          sign_in(users(:chief))
     end

     it "downloads exactly the filtered board tasks with complete columns and matching totals" do
          get tasks_path(filter: filter)
          board_titles = response.parsed_body.css(".task-card h3").map(&:text)
          expect(response.body).to include("8h actual of", "10h estimated")
          get tasks_path(format: :csv, filter: filter)
          expect(response.media_type).to eq("text/csv")
          expect(response.headers["Content-Disposition"]).to include("attachment", "tasks.csv")
          expect(csv_rows.headers).to eq(ReportCsv::TASK_HEADERS)
          expect(csv_rows.map { |row| row["Task"].delete_prefix("'") }).to match_array(board_titles)
          shared = csv_rows.find { |row| row["Task"] == @shared.title }
          expect(shared.to_h).to include("Estimated hours" => "10.0", "Actual hours" => "8.0", "Class" => team.name,
                                         "Subteam" => subteam.name, "Project" => project.name,
                                         "Start date" => day_one.iso8601, "Due date" => day_two.iso8601)
     end

     it "combines member, team, subteam, project, search and task-date filters and counts shared estimates once" do
          selection = filter.merge(member_id: @e.id, q: "Shared", task_from: day_two.iso8601, task_to: day_two.iso8601)
          get tasks_path(format: :csv, filter: selection, from: day_two, to: day_two)
          expect(csv_rows.size).to eq(1)
          expect(csv_rows.first.to_h).to include("Actual hours" => "2.5", "Estimated hours" => "10.0")
          get tasks_path(filter: selection, from: day_two, to: day_two)
          expect(response.body).to include("2.5h actual of", "10h estimated")
          get tasks_path(format: :csv, filter: filter.merge(task_from: (day_two + 1).iso8601))
          expect(csv_rows).to be_empty
     end

     it "exports the timeline's task rows and refreshes changed dates" do
          get timeline_path(filter: filter)
          ids = response.parsed_body.css("[data-gantt-row]").map { |row| row["data-task-id"].to_i }
          get timeline_path(format: :csv, filter: filter)
          expect(csv_rows.map { |row| row["Task"].delete_prefix("'") }).to match_array(Task.where(id: ids).pluck(:title))
          @shared.update!(due_date: day_two + 5)
          get timeline_path(format: :csv, filter: filter)
          expect(csv_rows.find { |row| row["Task"] == @shared.title }["Due date"]).to eq((day_two + 5).iso8601)
     end

     it "includes zero-hour members without assignments and matches on-screen member totals" do
          get member_hours_report_path(format: :csv, filter: filter)
          expect(csv_rows.headers).to eq(ReportCsv::MEMBER_HEADERS)
          expect(csv_rows.map { |row| [ row["Member"], row["Total actual hours"] ] }).to eq([
               [ "Member E", "5.0" ], [ "Member F", "3.0" ], [ "Member G", "0.0" ]
          ])
          expect(csv_rows.first.to_h).to include("Class" => team.name, "Subteam" => subteam.name, "Project" => project.name)
          get tasks_path(filter: filter)
          expect(response.parsed_body.at_css("[data-member='Member G']")["data-actual"]).to eq("0.0")
     end

     it "uses worked dates inclusively and applies member filters to both member and project hours" do
          get member_hours_report_path(format: :csv, filter: filter, from: day_two, to: day_two)
          expect(csv_rows.map { |row| row["Total actual hours"] }).to eq([ "2.5", "3.0", "0.0" ])
          get project_hours_report_path(format: :csv, filter: filter, from: day_two, to: day_two)
          expect(csv_rows.first["Total actual hours"]).to eq("5.5")
          get project_hours_report_path(format: :csv, filter: filter.merge(member_id: @e.id), from: day_two, to: day_two)
          expect(csv_rows.first["Total actual hours"]).to eq("2.5")
          get member_hours_report_path(format: :csv, filter: filter, from: day_two + 10, to: day_two + 11)
          expect(csv_rows.map { |row| row["Total actual hours"] }).to eq([ "0.0", "0.0", "0.0" ])
     end

     it "keeps zero members visible on an empty filtered board and returns header-only task downloads" do
          get tasks_path(filter: filter.merge(member_id: @g.id))
          expect(response.parsed_body.at_css("[data-member='Member G']")["data-actual"]).to eq("0.0")
          get tasks_path(format: :csv, filter: filter.merge(member_id: @g.id))
          expect(csv_rows).to be_empty
          get member_hours_report_path(format: :csv, filter: filter.merge(member_id: @g.id))
          expect(csv_rows.first["Total actual hours"]).to eq("0.0")
          get project_hours_report_path(format: :csv, filter: filter.merge(q: "does-not-exist"))
          expect(csv_rows).to be_empty
     end

     it "handles several selected teams but never exports another class to its officer" do
          get tasks_path(format: :csv, filter: { team_ids: [ team.id, teams(:structures).id ] })
          expect(csv_rows.map { |row| row["Class"] }.uniq).to contain_exactly(team.name, teams(:structures).name)
          sign_in(users(:officer))
          get tasks_path(format: :csv, filter: { team_ids: [ team.id, teams(:structures).id ] })
          expect(csv_rows.map { |row| row["Class"] }.uniq).to eq([ team.name ])
          get member_hours_report_path(format: :csv, filter: { project_id: projects(:airframe_build).id })
          expect(csv_rows).to be_empty
          get tasks_path(format: :csv, view: "mine", filter: { q: "" })
          expect(csv_rows).to be_empty
     end

     it "hides downloads from members and denies every direct CSV endpoint" do
          sign_in(users(:member))
          get tasks_path
          expect(response.body).not_to include("Download CSV", "Download member hours", "Download project hours")
          [ tasks_path(format: :csv), timeline_path(format: :csv), member_hours_report_path(format: :csv), project_hours_report_path(format: :csv) ].each do |path|
               get path
               expect(response).to have_http_status(:found)
               expect(flash[:alert]).to include("Access denied")
               expect(response.body).not_to include(@shared.title)
          end
     end

     it "preserves quotes, commas, newlines and accents while neutralizing spreadsheet formulas" do
          @shared.update!(title: "Ribs, \"quoted\"\né")
          get tasks_path(format: :csv, filter: filter)
          expect(csv_rows.map { |row| row["Task"] }).to include(@shared.title, "'=SUM(1,1)")
          expect(response.body.dup.force_encoding("UTF-8")).to start_with("\uFEFF")
          [ " +CMD", "\t@SUM(1,1)", "-1+1" ].each do |title|
               @shared.update!(title: title)
               get tasks_path(format: :csv, filter: filter)
               expect(csv_rows.map { |row| row["Task"] }).to include("'#{title}")
          end
     end

     it "shares invalid-hour-date fallback and supports reports without a project selection" do
          get member_hours_report_path(format: :csv, filter: filter.except(:project_id), from: "bad-date", to: "bad-date")
          expect(csv_rows.first["Project"]).to eq("All selected projects")
          get tasks_path(filter: filter, from: "2026-10-02", to: "2026-10-01")
          expect(response.body).to include("Showing hours for all dates")
     end
end
