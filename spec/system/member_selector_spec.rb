require "rails_helper"

RSpec.describe "Meeting task assignment", type: :system do
     before do
          driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ] do |options|
               options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
               options.add_argument("--no-sandbox") if Process.uid.zero?
               options.add_argument("--disable-dev-shm-usage")
          end
     end

     it "browses 80 members, searches with the keyboard, preserves selections and saves from a board column" do
          members = 80.times.map do |index|
               User.create!(name: format("Meeting Member %02d", index + 1), email: "meeting#{index}@tamu.edu",
                            role: :member, subteam: subteams(:wing))
          end
          visit login_path
          fill_in "Email address", with: users(:officer).email
          fill_in "Password", with: "password"
          click_button "Sign in", exact: true
          expect(page).to have_text("Task Board")
          visit new_task_path(return_to_board: "1", status: "completed", filter: { project_id: projects(:aero).id, subteam_id: subteams(:wing).id })
          expect(page).to have_select("Status", selected: "Completed")
          search = find("#task_member_search")
          # Exercise opening the selector at the bottom edge of the viewport.
          page.execute_script('arguments[0].scrollIntoView({block: "end"})', search)
          search.click
          expect(page).to have_css('#task_member_search[aria-expanded="true"]')
          expect(page).to have_css('#member-options:not([hidden])', visible: true)
          expect(page.evaluate_script('document.getElementById("member-options").getBoundingClientRect().bottom <= window.innerHeight + 1')).to be(true)
          # All choices belong in the bounded list, including scrolled-out rows.
          expect(page).to have_css('#member-options [role="option"]', count: 82, visible: :all)
          expect(page).to have_css('#member-options [role="option"]', text: "Meeting Member 01", visible: true)
          expect(page.evaluate_script('document.getElementById("member-options").getBoundingClientRect().height')).to be <= 300
          expect(page).not_to have_css('input[type="checkbox"]')
          expect(page).not_to have_css('#member-options [role="option"]', text: users(:other_member).name, visible: :all)
          search.fill_in(with: "meeting MEMBER 70")
          search.send_keys(:arrow_down, :enter)
          expect(page).to have_css('button[aria-label="Remove Meeting Member 70"]')
          search.fill_in(with: "Member 80")
          search.send_keys(:arrow_down, :enter)
          expect(page).to have_css('button[aria-label="Remove Meeting Member 80"]')
          expect(page).to have_css('button[aria-label="Remove Meeting Member 70"]')
          search.fill_in(with: "No person has this name")
          expect(page).to have_text("No matching members")
          find('button[aria-label="Remove Meeting Member 70"]').click
          expect(page).not_to have_css('button[aria-label="Remove Meeting Member 70"]')
          expect(page).to have_css('button[aria-label="Remove Meeting Member 80"]')
          search.send_keys(:escape)
          expect(page).not_to have_css("#member-options", visible: true)
          select "Meeting Member 80", from: "Primary contact (optional)"
          due_date = Date.current + 7
          # Chromium's date input uses locale-dependent segmented keystrokes.
          page.execute_script('document.getElementById("task_due_date").value = arguments[0]', due_date.iso8601)
          expect(page).to have_field("Due date", with: due_date.iso8601)
          fill_in "Estimated hours", with: "2"
          fill_in "Expected deliverables (optional)", with: "Keep this note"
          page.execute_script('document.querySelector("form.task-form").noValidate = true')
          click_button "Create Task"
          expect(page).to have_text("Title can't be blank")
          expect(page).to have_field("Expected deliverables (optional)", with: "Keep this note")
          expect(page).to have_css('button[aria-label="Remove Meeting Member 80"]')
          page.driver.browser.manage.window.resize_to(390, 844)
          find("#task_member_search").click
          page.execute_script('document.querySelector("[data-member-selector]").scrollIntoView({block: "start"})')
          expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth + 1")).to be(true)
          page.save_screenshot(Rails.root.join("tmp/screenshots/member_selector.png"))
          fill_in "Title", with: "Meeting task saved"
          click_button "Create Task"
          expect(page).to have_text("Task was created successfully.")
          within(find("#completed-heading").find(:xpath, "../..")) do
               expect(page).to have_link("Meeting task saved")
          end
          task = Task.find_by!(title: "Meeting task saved")
          expect(task.assignee_ids).to eq([ members.last.id ])
          expect(task.primary_contact).to eq(members.last)
          expect(task.due_date).to eq(due_date)
          expect(task.status_changes.first.to_status).to eq("completed")
     end
end
