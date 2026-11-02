require "rails_helper"

RSpec.describe "Meeting task assignment", type: :system do
     before do
          driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ] do |options|
               options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
               options.add_argument("--no-sandbox") if Process.uid.zero?
               options.add_argument("--disable-dev-shm-usage")
               # Rails resizes the window after launch; configure the virtual display too.
               options.add_argument("--screen-info={1600x1200}")
               options.add_argument("--window-size=1280,1000")
               options.add_argument("--window-position=0,0")
          end
     end

     after do |example|
          next unless example.exception

          begin
               details = page.evaluate_script(<<~JS)
                 (() => {
                   const describe = node => node ? node.id || node.nodeName : null;
                   const input = document.getElementById("task_member_search");
                   const rect = input?.getBoundingClientRect();
                   return {
                     browser: navigator.userAgent,
                     documentFocused: document.hasFocus(),
                     activeElement: describe(document.activeElement),
                     screen: {width: screen.width, height: screen.height,
                              availableWidth: screen.availWidth, availableHeight: screen.availHeight},
                     window: {width: outerWidth, height: outerHeight, x: screenX, y: screenY},
                     viewport: {width: innerWidth, height: innerHeight},
                     input: rect ? {rect: rect.toJSON(), expanded: input.getAttribute("aria-expanded"),
                                    disabled: input.disabled, pointerEvents: getComputedStyle(input).pointerEvents} : null,
                     centerTarget: rect ? describe(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2)) : null,
                     events: window.memberSelectorEvents || []
                   };
                 })()
               JS
               message = "#{example.exception.message}\nBrowser diagnostics: #{details.to_json}"
               if ENV["GITHUB_ACTIONS"] == "true"
                    # Escape workflow-command data so the failure is readable through GitHub's checks API.
                    escaped = message.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
                    warn "::error file=spec/system/member_selector_spec.rb,title=Member selector browser failure::#{escaped}"
               else
                    warn message
               end
          rescue StandardError => error
               warn "Could not capture browser diagnostics: #{error.class}"
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
          page.execute_script(<<~JS)
            window.memberSelectorEvents = [];
            for (const type of ["pointerdown", "mousedown", "pointerup", "mouseup", "click", "focusin", "focusout"]) {
              document.addEventListener(type, event => {
                window.memberSelectorEvents.push({type: event.type, target: event.target.id || event.target.nodeName,
                  active: document.activeElement.id || document.activeElement.nodeName,
                  x: event.clientX, y: event.clientY});
                if (window.memberSelectorEvents.length > 20) window.memberSelectorEvents.shift();
              }, true);
            }
          JS
          # Exercise opening the selector at the bottom edge of the viewport.
          page.execute_script('arguments[0].scrollIntoView({block: "end"})', search)
          expect(page.evaluate_script("outerWidth <= screen.availWidth && outerHeight <= screen.availHeight")).to be(true),
               "Chrome's virtual screen must contain the test window"
          search_top = page.evaluate_script('document.getElementById("task_member_search").getBoundingClientRect().top')
          begin
               page.driver.browser.action.move_to(search.native).click_and_hold.perform
               # Moving the field during pointer-down can send the click elsewhere.
               expect(page.evaluate_script('document.getElementById("task_member_search").getBoundingClientRect().top')).to be_within(1).of(search_top)
          ensure
               page.driver.browser.action.release.perform
          end
          expect(page).to have_css("#task_member_search:focus")
          expect(page).to have_css('#task_member_search[aria-expanded="true"]')
          find("#task_estimated_hours").click
          expect(page).to have_css('#task_member_search[aria-expanded="false"]')
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
          expect(page).not_to have_css(".member-chip")
          search.send_keys(:tab)
          expect(page).to have_css("#task_primary_contact_id:focus")
          expect(page).to have_css('#task_member_search[aria-expanded="false"]')
          find("#task_primary_contact_id").send_keys([ :shift, :tab ])
          expect(page).to have_css('#task_member_search:focus[aria-expanded="true"]')
          expect(page).to have_css('#member-options:not([hidden])', visible: true)
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
          expect(page).to have_css('#task_member_search:focus[aria-expanded="true"]')
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
