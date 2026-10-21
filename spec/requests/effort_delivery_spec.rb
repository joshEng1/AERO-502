require "rails_helper"

RSpec.describe "Effort and dashboard delivery", type: :request do
     it "renders hour constraints that accept ordinary positive decimal entries" do
          sign_in(users(:member))
          get task_path(tasks(:wing_test))

          field = response.parsed_body.at_css('input[name="time_entry[hours]"]')
          minimum = BigDecimal(field["min"])
          step = BigDecimal(field["step"])
          expect(minimum).to be > 0
          [ "0.01", "1", "1.5", "2.5" ].each do |value|
               hours = BigDecimal(value)
               expect(hours).to be >= minimum
               expect((hours - minimum) % step).to eq(0), "browser step rejects #{value} hours"
          end
     end

     it "records hours, date, and note for the signed-in assignee despite a forged user id" do
          task = tasks(:wing_test)
          member = users(:member)
          worked_on = Date.new(2026, 9, 30)
          sign_in(member)

          expect do
               post task_time_entries_path(task), params: {
                    time_entry: {
                         hours: "1.75", worked_on: worked_on.iso8601,
                         note: "Measured wing deflection", user_id: users(:other_member).id
                    }
               }
          end.to change(TimeEntry, :count).by(1)

          entry = TimeEntry.order(:id).last
          expect(response).to redirect_to(task_path(task))
          expect(entry).to have_attributes(
               task_id: task.id, user_id: member.id, hours: 1.75,
               worked_on: worked_on, note: "Measured wing deflection"
          )
          expect(task.reload.total_actual_hours).to eq(4.25)
     end

     it "refuses zero, negative, and undated hours, and refuses an unassigned member" do
          task = tasks(:wing_test)
          sign_in(users(:member))

          [
               { hours: 0, worked_on: Date.current },
               { hours: -0.5, worked_on: Date.current },
               { hours: 1, worked_on: "" }
          ].each do |invalid_entry|
               expect do
                    post task_time_entries_path(task), params: { time_entry: invalid_entry }
               end.not_to change(TimeEntry, :count)
               expect(response).to redirect_to(task_path(task))
               expect(task.reload.total_actual_hours).to eq(2.5)
          end

          sign_in(users(:other_member))
          expect do
               post task_time_entries_path(task), params: {
                    time_entry: { hours: 2, worked_on: Date.current }
               }
          end.not_to change(TimeEntry, :count)
          expect(response).to redirect_to(root_path)
          expect(task.reload.total_actual_hours).to eq(2.5)
     end

     it "shows 4 plus 3 hours once on the detail page and the chief's board summary" do
          task, first_member, second_member = shared_task_with_hours
          sign_in(users(:chief))

          get task_path(task)
          expect(response).to have_http_status(:success)
          effort = response.parsed_body.at_css(".effort-numbers")
          expect(effort.css("strong").map(&:text)).to eq([ "8h", "7h", "-1h" ])
          member_cards = response.parsed_body.css(".member-grid article")
          expect(member_cards.map { |card| card.text.squish }).to include(
               "#{first_member.name} 4 hours", "#{second_member.name} 3 hours"
          )

          get tasks_path
          expect(response).to have_http_status(:success)
          card = response.parsed_body.css(".task-card").find { |item| item.text.include?(task.title) }
          expect(card).to be_present
          expect(card.at_css(".task-foot strong").text).to eq("7/8h")

          expect(response.parsed_body.at_css("[data-board-summary]").text.squish).to include("11h actual")
          counts = response.parsed_body.css(".column-heading").map { |heading| heading.css("h2, span").map(&:text) }
          expect(counts).to eq([ [ "Backlog", "2" ], [ "In progress", "1" ], [ "Completed", "0" ] ])
          workload = response.parsed_body.css("[data-member-hours] tbody tr").map { |item| item.text.squish }
          expect(workload).to include(a_string_starting_with("#{first_member.name} 18 hours 6.5 hours"),
                                      a_string_starting_with("#{second_member.name} 8 hours 3 hours"))
     end

     it "shows an assigned shared task once on the member's board and keeps hours for leaders" do
          task, first_member, = shared_task_with_hours
          sign_in(first_member)

          get root_path
          expect(response).to have_http_status(:success)
          expect(response.parsed_body.css(".task-card").count).to eq(2)
          expect(response.parsed_body.css(".task-card").count { |card| card.text.include?(task.title) }).to eq(1)
          expect(response.body).not_to include(tasks(:spar_check).title)
          expect(response.parsed_body.at_css("[data-member-hours]")).to be_nil
     end

     it "explains an empty assignment list on the member board" do
          member = User.create!(
               name: "Unassigned Member", email: "unassigned@example.test",
               password: "password", role: :member, team: teams(:aerodynamics)
          )
          sign_in(member)

          get tasks_path
          expect(response).to have_http_status(:success)
          expect(response.body).to include("No tasks found", "There are no permitted tasks on this board.")
     end

     private

     def sign_in(user)
          post login_path, params: { email: user.email, password: "password" }
     end

     def shared_task_with_hours
          first_member = users(:member)
          second_member = User.create!(
               name: "Sam Second", email: "sam.second@example.test",
               password: "password", role: :member, team: teams(:aerodynamics)
          )
          task = Task.create!(
               title: "Shared effort check", description: "Measure shared effort.",
               start_date: Date.new(2026, 10, 1),
               estimated_hours: 8, due_date: Date.new(2026, 10, 20), status: :backlog, project: projects(:aero),
               team: teams(:aerodynamics), creator: users(:officer)
          )
          [ first_member, second_member ].each do |member|
               TaskAssignment.create!(task: task, user: member)
          end
          TimeEntry.create!(task: task, user: first_member, hours: 4, worked_on: Date.new(2026, 9, 28))
          TimeEntry.create!(task: task, user: second_member, hours: 3, worked_on: Date.new(2026, 9, 29))
          [ task, first_member, second_member ]
     end
end
