require "rails_helper"

# KAN-25: sign in with a Google (TAMU) account on the allowed-users list.
RSpec.describe "Google sign-in", type: :request do
     before do
          @previous_test_mode = OmniAuth.config.test_mode
          OmniAuth.config.test_mode = true
     end
     after do
          OmniAuth.config.mock_auth[:google_oauth2] = nil
          OmniAuth.config.test_mode = @previous_test_mode
     end

     def google_sign_in(email, verified: true, client: self)
          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
               provider: "google_oauth2", uid: "google-#{email}",
               info: { email: email, name: "Google Name", role: "chief_engineer" },
               extra: { raw_info: { email_verified: verified } }
          )
          client.post "/auth/google_oauth2"
          client.follow_redirect!
     end

     it "offers Sign in with Google on the sign-in page" do
          get login_path

          expect(response.parsed_body.at_css("form[action='/auth/google_oauth2'] button").text).to include("Sign in with Google")
     end

     it "signs in an allowed email with the role and team assigned to it, ignoring letter case" do
          google_sign_in("Officer@Example.TEST")

          expect(response).to redirect_to(root_path)
          follow_redirect!
          expect(response.body).to include("Olivia Officer · Officer", "Wing load test")
     end

     it "keeps the assigned role, class and subteam for every role across independent sessions" do
          %i[chief officer member].each do |role|
               person = users(role)
               person.update!(subteam: subteams(:wing)) unless person.chief_engineer?
               assigned_attributes = { "role" => person.role, "team_id" => person.team_id, "subteam_id" => person.subteam_id, "name" => person.name }

               2.times do
                    client = ActionDispatch::Integration::Session.new(Rails.application)
                    google_sign_in(person.email.upcase, client: client)
                    expect(client.response.status).to eq(302)
                    expect(client.response.location).to eq("http://www.example.com#{root_path}")
                    client.follow_redirect!
                    expect(client.response.body).to include("#{person.name} · #{person.role_label}")
                    person.reload
                    expect(assigned_attributes.keys.to_h { |key| [ key, person.public_send(key) ] }).to eq(assigned_attributes)
                    client.get users_path
                    expect(client.response.status).to eq(person.chief_engineer? ? 200 : 302)
                    expect(client.response.body).to include("People") if person.chief_engineer?
               end
          end
     end

     it "refuses accounts that are not on the list or whose email Google has not verified" do
          [ [ "stranger@tamu.edu", true ], [ users(:member).email, false ],
            [ users(:member).email, "false" ], [ users(:member).email, nil ] ].each do |email, verified|
               google_sign_in(email, verified: verified)

               expect(response).to redirect_to(login_path)
               follow_redirect!
               expect(response.body).to include("Access not authorized")
               expect(response.parsed_body.at_css("[role='alert']").text).to include("Access not authorized")
               expect(response.body).not_to include("Wing load test", "Verify spar dimensions")
               get tasks_path
               expect(response).to redirect_to(login_path)
          end
     end

     it "clears an existing session on rejected Google sign-in and allows choosing an approved account afterwards" do
          sign_in(users(:chief))
          google_sign_in("stranger@tamu.edu")
          get tasks_path
          expect(response).to redirect_to(login_path)
          get users_path
          expect(response).to redirect_to(login_path)

          google_sign_in(users(:member).email)
          expect(response).to redirect_to(root_path)
          follow_redirect!
          expect(response.body).to include("Morgan Member · Member")
          expect(response.body).not_to include("Verify spar dimensions")
     end

     it "explains a cancelled or failed Google sign-in" do
          sign_in(users(:chief))
          get "/auth/failure", params: { message: "access_denied" }

          expect(response).to redirect_to(login_path)
          expect(flash[:alert]).to eq("Google sign-in was cancelled or failed. Please try again.")
          get users_path
          expect(response).to redirect_to(login_path)
     end

     it "lets the Chief Engineer add an allowed person who can then sign in on the first try" do
          sign_in(users(:chief))
          get new_user_path
          expect(response).to have_http_status(:ok)

          expect do
               post users_path, params: { user: {
                    name: "Riley Recruit", email: "Riley@TAMU.edu", role: "member",
                    team_id: teams(:aerodynamics).id, subteam_id: subteams(:wing).id
               } }
          end.to change(User, :count).by(1)
          expect(response).to redirect_to(users_path)
          expect(User.find_by(email: "riley@tamu.edu")).to have_attributes(password_digest: nil, subteam: subteams(:wing))

          delete logout_path
          google_sign_in("RILEY@TAMU.EDU")
          follow_redirect!
          expect(response.body).to include("Riley Recruit · Member")
     end

     it "shows errors when an added person is incomplete" do
          sign_in(users(:chief))

          expect { post users_path, params: { user: { name: "", email: "bad", role: "member" } } }
               .not_to change(User, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.at_css("#user_email_error").text).to include("Email is invalid")
     end

     it "signs a removed person out at their next page load but keeps their tasks and hours" do
          member = users(:member)
          google_sign_in(member.email)

          member.update!(access_revoked_at: Time.current)

          get tasks_path
          expect(response).to redirect_to(login_path)
          expect(flash[:alert]).to include("Access not authorized")
          expect(member.time_entries.count).to eq(1)
          expect(tasks(:wing_test).assignees).to include(member)

          google_sign_in(member.email)
          expect(response).to redirect_to(login_path)
          post login_path, params: { email: member.email, password: "password" }
          expect(response.body).to include("Access not authorized")
     end

     it "lets the Chief Engineer remove and restore a person's access from the People screen" do
          sign_in(users(:chief))

          patch revoke_user_path(users(:member))
          expect(response).to redirect_to(users_path)
          expect(users(:member).reload.access_revoked_at).to be_present
          get users_path
          expect(response.body).to include("Access removed")

          patch restore_user_path(users(:member))
          expect(users(:member).reload.access_revoked_at).to be_nil
     end

     it "rejects an open task action after a chief revokes access in another session, preserving past work" do
          member = users(:member)
          task = tasks(:wing_test)
          google_sign_in(member.email)
          get task_path(task)
          expect(response).to have_http_status(:ok)
          original_hours = member.time_entries.sum(:hours)
          original_assignments = member.assigned_task_ids

          administrator = ActionDispatch::Integration::Session.new(Rails.application)
          administrator.post login_path, params: { email: users(:chief).email, password: "password" }
          administrator.patch revoke_user_path(member)
          expect(administrator.response.status).to eq(302)
          expect(administrator.response.location).to eq("http://www.example.com#{users_path}")

          patch task_path(task), params: { task: { status: "completed" } }
          expect(response).to redirect_to(login_path)
          expect(flash[:alert]).to include("Access not authorized")
          expect(task.reload.status).to eq("backlog")
          expect(member.time_entries.sum(:hours)).to eq(original_hours)
          expect(member.assigned_task_ids).to match_array(original_assignments)
          google_sign_in(member.email)
          expect(response).to redirect_to(login_path)
     end

     it "ends a revoked session even when the next page is the public user guide" do
          google_sign_in(users(:member).email)
          users(:member).update!(access_revoked_at: Time.current)

          get help_path
          expect(response).to redirect_to(login_path)
          expect(flash[:alert]).to include("Your access has been removed")
          follow_redirect!
          expect(response.body).not_to include("Morgan Member")
          get help_path
          expect(response).to have_http_status(:ok)
     end

     it "gives officers and members no option to add or remove allowed people" do
          [ users(:officer), users(:member) ].each do |user|
               sign_in(user)
               get tasks_path
               expect(response.parsed_body.css("header a[href='#{users_path}']")).to be_empty
               get users_path
               expect(response).to redirect_to(root_path)
               expect(flash[:alert]).to include("Access denied")
               get new_user_path
               expect(response).to redirect_to(root_path)
               expect { post users_path, params: { user: { name: "X", email: "x@tamu.edu", role: "member" } } }
                    .not_to change(User, :count)
               patch revoke_user_path(users(:other_member))
               expect(users(:other_member).reload.access_revoked_at).to be_nil
               users(:other_member).update!(access_revoked_at: Time.current)
               patch restore_user_path(users(:other_member))
               expect(users(:other_member).reload.access_revoked_at).to be_present
               users(:other_member).update!(access_revoked_at: nil)
          end
     end

     it "refuses password sign-in when it has been turned off" do
          allow(Rails.configuration.x).to receive(:password_sign_in).and_return(false)
          post login_path, params: { email: users(:member).email, password: "password" }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Password sign-in is turned off. Use Sign in with Google.")
     end

     it "refuses password sign-in for a person who has no password" do
          person = User.create!(name: "Google Only", email: "google.only@tamu.edu", role: :member, subteam: subteams(:wing))
          post login_path, params: { email: person.email, password: "" }

          expect(response.body).to include("Access not authorized")
     end
end
