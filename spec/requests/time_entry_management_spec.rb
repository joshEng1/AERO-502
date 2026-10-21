require "rails_helper"

# KAN-13: members record, correct and remove their own dated hours.
RSpec.describe "Recording actual hours", type: :request do
     let(:task) { tasks(:wing_test) }
     let(:member) { users(:member) }
     let(:entry) { time_entries(:wing_hours) }

     def log_hours(hours, worked_on: "2026-09-30")
          post task_time_entries_path(task), params: { time_entry: { hours: hours, worked_on: worked_on } }
     end

     it "confirms a saved entry and lists it on the task with its date, member and hours" do
          sign_in(member)
          log_hours("1.5")
          follow_redirect!

          expect(response.body).to include("Hours were recorded.")
          rows = response.parsed_body.css("[data-time-entry]").map(&:text)
          expect(rows).to include(a_string_including("September 30, 2026", "Morgan Member", "1.5 hours"))
     end

     it "explains each limit when hours are zero or less, over 24, or not a number" do
          sign_in(member)

          {
               "0" => "Hours must be greater than 0",
               "-1" => "Hours must be greater than 0",
               "25" => "a member can record at most 24 hours per day",
               "abc" => "Hours is not a number"
          }.each do |hours, message|
               expect { log_hours(hours) }.not_to change(TimeEntry, :count)
               follow_redirect!
               expect(response.body).to include(message)
          end
     end

     it "limits a member's total for one worked date to 24 hours across all tasks" do
          other_task = Task.create!(title: "Second task", estimated_hours: 2, due_date: Date.new(2026, 10, 20),
                                    start_date: Date.new(2026, 10, 1),
                                    project: projects(:aero), team: teams(:aerodynamics), creator: users(:officer))
          other_task.assignees << member
          TimeEntry.create!(task: other_task, user: member, hours: 20, worked_on: Date.new(2026, 9, 30))
          sign_in(member)

          expect { log_hours("4") }.to change(TimeEntry, :count).by(1)
          expect { log_hours("0.5") }.not_to change(TimeEntry, :count)
          expect { log_hours("0.5", worked_on: "2026-10-01") }.to change(TimeEntry, :count).by(1)
     end

     it "lets a member correct their own entry and keeps the 24-hour limit on edits" do
          sign_in(member)
          get edit_time_entry_path(entry)
          expect(response).to have_http_status(:ok)

          patch time_entry_path(entry), params: { time_entry: { hours: "3.25", worked_on: "2026-09-29" } }
          expect(response).to redirect_to(task_path(task))
          expect(entry.reload).to have_attributes(hours: 3.25, worked_on: Date.new(2026, 9, 29))

          patch time_entry_path(entry), params: { time_entry: { hours: "24.5" } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("at most 24 hours per day")
          expect(entry.reload.hours).to eq(3.25)
     end

     it "lets a member remove their own entry and updates the task total" do
          sign_in(member)

          expect { delete time_entry_path(entry) }.to change(TimeEntry, :count).by(-1)
          expect(response).to redirect_to(task_path(task))
          expect(task.reload.total_actual_hours).to eq(0)
     end

     it "refuses to let anyone change or remove another member's entry" do
          second = User.create!(name: "Sam Second", email: "sam@example.test", password: "password",
                                role: :member, team: teams(:aerodynamics))
          task.assignees << second
          sign_in(second)

          get edit_time_entry_path(entry)
          expect(response).to redirect_to(root_path)
          patch time_entry_path(entry), params: { time_entry: { hours: "9" } }
          expect { delete time_entry_path(entry) }.not_to change(TimeEntry, :count)
          expect(entry.reload.hours).to eq(2.5)

          get task_path(task)
          expect(response.parsed_body.css("[data-time-entry] a, [data-time-entry] button")).to be_empty
     end

     it "shows edit and delete controls only on the member's own entries" do
          sign_in(member)
          get task_path(task)

          row = response.parsed_body.at_css("[data-time-entry]")
          expect(row.at_css("a[href='#{edit_time_entry_path(entry)}']")).to be_present
          expect(row.at_css("form[action='#{time_entry_path(entry)}']")).to be_present
     end

     it "shows the total of all assignees' hours, the estimate and the difference" do
          sign_in(member)
          get task_path(task)

          effort = response.parsed_body.at_css(".effort-numbers").text
          expect(effort).to include("10h", "2.5h", "-7.5h")
     end
end
