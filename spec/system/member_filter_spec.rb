require "rails_helper"

RSpec.describe "Searchable member filter", type: :system do
     before do
          driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ] do |options|
               options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
               options.add_argument("--no-sandbox") if Process.uid.zero?
               options.add_argument("--disable-dev-shm-usage")
               options.add_argument("--screen-info={1600x1200}")
               options.add_argument("--window-size=1280,1000")
               options.add_argument("--window-position=0,0")
               options.add_preference("credentials_enable_service", false)
               options.add_preference("profile.password_manager_leak_detection", false)
          end
     end

     it "searches 80 members and keeps the selected ID and other filters across board and timeline" do
          members = 80.times.map do |index|
               User.create!(name: format("Meeting Member %02d", index + 1), email: "filter#{index}@tamu.edu",
                            role: :member, subteam: subteams(:wing))
          end
          visit login_path
          fill_in "Email address", with: users(:officer).email
          fill_in "Password", with: "password"
          click_button "Sign in", exact: true
          expect(page).to have_text("Task Board")
          visit tasks_path(filter: { q: "Wing", project_id: projects(:aero).id, team_id: teams(:aerodynamics).id,
                                     subteam_id: subteams(:wing).id, task_from: "2026-09-28", task_to: "2026-10-05" })

          search = find("#filter_member_id_search")
          search.click
          expect(page).to have_css('.member-filter-popup:not([hidden])')
          expect(page).to have_css('#filter_member_id_options [role="option"]', count: 83, visible: :all)
          expect(page).not_to have_css('#filter_member_id_options [role="option"]', text: users(:other_member).name)
          expect(page.evaluate_script('document.getElementById("filter_member_id_options").getBoundingClientRect().height')).to be <= 300
          search.fill_in(with: "mEmBeR 70")
          search.send_keys(:arrow_down, :enter)
          expect(page).to have_field("Member", with: "Meeting Member 70")
          expect(find("#filter_member_id", visible: :all).value).to eq(members[69].id.to_s)
          search.fill_in(with: "Nobody matches this name")
          expect(page).to have_text("No matching members")
          search.send_keys(:escape)
          expect(page).to have_field("Member", with: "Meeting Member 70")

          click_button "Apply", exact: true
          expect(page).to have_text("No tasks match your search or filters.")
          expect(page).to have_field("Member", with: "Meeting Member 70")
          expect(page).to have_field("Search tasks", with: "Wing")
          expect(page).to have_select("Project", selected: projects(:aero).full_name)
          expect(page).to have_select("Team", selected: teams(:aerodynamics).name)
          expect(page).to have_select("Subteam", selected: subteams(:wing).full_name)
          expect(page).to have_field("Task dates from", with: "2026-09-28")
          expect(page).to have_field("Task dates to", with: "2026-10-05")

          click_link "Timeline", exact: true
          expect(page).to have_field("Member", with: "Meeting Member 70")
          find('button[aria-label="Clear member filter"]').click
          expect(page).to have_field("Member", with: "")
          click_button "Apply", exact: true
          expect(page).to have_link("Wing load test")
          expect(page).to have_field("Search tasks", with: "Wing")
          expect(page).to have_select("Project", selected: projects(:aero).full_name)

          search = find_field("Member")
          search.click
          search.send_keys("mOrGaN")
          find('#filter_member_id_options [role="option"]', text: "Morgan Member").click
          click_button "Apply", exact: true
          expect(page).to have_field("Member", with: "Morgan Member")
          export_query = URI.decode_www_form(URI.parse(find_link("Download timeline CSV")[:href]).query).to_h
          expect(export_query["filter[member_id]"]).to eq(users(:member).id.to_s)

          page.driver.browser.manage.window.resize_to(390, 844)
          find_field("Member").click
          expect(page).to have_css('#filter_member_id_search[aria-expanded="true"]')
          expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth + 1")).to be(true)
          find('#filter_member_id_options [role="option"]', text: "All members", exact_text: true).click
          click_button "Apply", exact: true
          expect(page).to have_field("Member", with: "")
          expect(page).to have_link("Wing load test")
     end
end
