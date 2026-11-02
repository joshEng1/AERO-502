require "rails_helper"

# KAN-9: sign in with role-based access.
RSpec.describe "Role-based access", type: :request do
     it "tells a person without an approved account that access is not authorized" do
          [ "stranger@example.test", users(:member).email ].each do |email|
               post login_path, params: { email: email, password: "wrong-password" }

               expect(response).to have_http_status(:unprocessable_content)
               expect(response.body).to include("Access not authorized")
               expect(response.body).not_to include("Wing load test")
          end
          get tasks_path
          expect(response).to redirect_to(login_path)
     end

     it "blocks an officer from changing another team's task and explains why" do
          sign_in(users(:officer))
          patch task_path(tasks(:spar_check)), params: { task: { title: "Hijacked" } }

          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("You can manage only tasks on your own team.")
          expect(tasks(:spar_check).reload.title).to eq("Verify spar dimensions")
     end

     it "lets the Chief Engineer change a user's role, shown on their account at the next page load" do
          sign_in(users(:chief))
          get users_path
          expect(response.body).to include("Morgan Member", "Member")

          patch user_path(users(:member)), params: { user: { role: "officer", team_id: teams(:aerodynamics).id } }
          expect(response).to redirect_to(users_path)
          expect(flash[:notice]).to eq("Morgan Member is now an Officer.")
          expect(users(:member).reload).to be_officer

          sign_in(users(:member))
          get new_task_path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Morgan Member · Officer")
     end

     it "keeps the previous role when the change is invalid" do
          sign_in(users(:chief))
          patch user_path(users(:member)), params: { user: { role: "officer", subteam_id: "" } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Subteam is required for a member or officer")
          expect(users(:member).reload).to be_member
     end

     it "gives officers and members no option to change roles" do
          [ users(:officer), users(:member) ].each do |user|
               sign_in(user)
               get tasks_path
               expect(response.body).not_to include(users_path)

               [ -> { get users_path }, -> { get edit_user_path(users(:other_member)) } ].each do |request|
                    request.call
                    expect(response).to redirect_to(root_path)
               end
               patch user_path(users(:other_member)), params: { user: { role: "chief_engineer" } }
               expect(users(:other_member).reload).to be_member
          end
     end
end
