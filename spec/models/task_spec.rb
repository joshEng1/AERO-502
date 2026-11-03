require "rails_helper"

RSpec.describe Task, type: :model do
     it "derives its team from its project and subteams from active assignees" do
          task = tasks(:wing_test)
          expect(task.project).to eq(projects(:aero))
          expect(task.subteams).to contain_exactly(subteams(:wing))
          expect(task.team).to eq(teams(:aerodynamics))
          expect(Task.column_names).not_to include("project_subteam_id", "team_id", "subteam_id")
     end

     it "calculates member hours consistently with preloaded entries" do
          task = tasks(:wing_test)
          task.time_entries.load
          expect(task.actual_hours_for(users(:member))).to eq(2.5)
          expect(task.actual_hours_for(users(:other_member))).to eq(0)
     end
     it "rejects a negative estimate without changing the saved value" do
          task = tasks(:wing_test)
          task.estimated_hours = -1

          expect(task.save).to be_falsey
          expect(task.errors[:estimated_hours]).to include("must be greater than or equal to 0")
          expect(task.reload.estimated_hours).to eq(10)
     end

     it "accessible scope follows role and assignment" do
          expect(Task.accessible_to(users(:chief)).count).to eq(2)
          expect(Task.accessible_to(users(:officer)).to_a).to eq([ tasks(:wing_test) ])
          expect(Task.accessible_to(users(:member)).to_a).to eq([ tasks(:wing_test) ])
          expect(Task.accessible_to(users(:member)).where(id: tasks(:spar_check))).to be_empty
     end

     it "reports actual totals and variance" do
          task = tasks(:wing_test)

          expect(task.total_actual_hours).to eq(2.5)
          expect(task.actual_hours_for(users(:member))).to eq(2.5)
          expect(task.variance_hours).to eq(-7.5)
     end

     it "accepts only full http and https web addresses as reference links" do
          task = tasks(:wing_test)

          [ "not a link", "ftp://example.com/file", "https://", "example.com/page" ].each do |url|
               task.reference_links_text = url
               expect(task).not_to be_valid, "#{url} should be rejected"
               expect(task.errors[:reference_links_text]).to include(Task::LINK_FORMAT_MESSAGE)
          end

          task.reference_links_text = " http://example.com/a \r\n\r\nhttps://example.com/b "
          expect(task).to be_valid
          expect(task.reference_links_text).to eq("http://example.com/a\nhttps://example.com/b")
     end

     it "lists saved links in order and keeps them when other fields change" do
          task = tasks(:wing_test)

          expect(task.reference_links_text).to eq("https://example.com/wing")
          task.update!(title: "Renamed wing test")
          expect(task.reload.reference_urls).to eq([ "https://example.com/wing" ])
     end

     it "defaults the start date to today and requires a due date on or after it" do
          task = Task.new
          expect(task.start_date).to eq(Date.current)

          task.due_date = Date.current - 1
          task.valid?
          expect(task.errors[:due_date]).to include("must be on or after the start date")

          task.start_date = nil
          task.valid?
          expect(task.errors[:start_date]).to include("can't be blank")
          expect(task.errors[:due_date]).not_to include("must be on or after the start date")
     end
end
