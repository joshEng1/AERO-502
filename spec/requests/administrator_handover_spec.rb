require "rails_helper"

# KAN-26: hand over administrator access without leaving the organization locked out.
RSpec.describe "Administrator handover", type: :request do
     let(:chief) { users(:chief) }
     let(:successor) { users(:other_officer) }
     let(:required_message) { "At least one active Chief Engineer is required" }

     before { sign_in(chief) }

     it "blocks a direct request to demote the last active chief and explains the next step" do
          patch user_path(chief), params: { user: { role: "member", subteam_id: subteams(:wing).id } }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.at_css("[role='alert']").text).to include(required_message, "Add another Chief Engineer")
          expect(chief.reload).to be_chief_engineer
          expect(chief.team_id).to be_nil
          get users_path
          expect(response).to have_http_status(:ok)
     end

     it "blocks a direct request to revoke the last chief and keeps their session usable" do
          patch revoke_user_path(chief)

          expect(response).to redirect_to(users_path)
          expect(flash[:alert]).to include(required_message)
          expect(chief.reload).not_to be_access_revoked
          follow_redirect!
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(required_message)
     end

     it "does not count a revoked Chief Engineer as a replacement administrator" do
          successor.update!(subteam: nil, role: :chief_engineer, access_revoked_at: Time.current)

          patch revoke_user_path(chief)
          expect(chief.reload).not_to be_access_revoked
          expect(flash[:alert]).to include(required_message)

          patch user_path(chief), params: { user: { role: "officer", subteam_id: subteams(:wing).id } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(chief.reload).to be_chief_engineer
     end

     it "allows an incoming chief to take over and demote the outgoing chief" do
          patch user_path(successor), params: { user: { role: "chief_engineer" } }
          expect(successor.reload).to be_chief_engineer
          get users_path
          expect(response).to have_http_status(:ok)

          sign_in(successor)
          get users_path
          expect(response).to have_http_status(:ok)
          patch user_path(chief), params: { user: { role: "member", subteam_id: subteams(:wing).id } }

          expect(response).to redirect_to(users_path)
          expect(chief.reload).to be_member
          sign_in(chief)
          get users_path
          expect(response).to redirect_to(root_path)
     end

     it "allows revoking an outgoing chief when another active chief remains, preserving their records" do
          successor.update!(subteam: nil, role: :chief_engineer)
          assignments = successor.task_assignments.pluck(:id)
          entries = successor.time_entries.pluck(:id)

          patch revoke_user_path(successor)

          expect(response).to redirect_to(users_path)
          expect(successor.reload).to be_access_revoked
          expect(successor.task_assignments.pluck(:id)).to match_array(assignments)
          expect(successor.time_entries.pluck(:id)).to match_array(entries)
          expect(chief.reload).to be_chief_engineer
          expect(chief).not_to be_access_revoked
     end

     it "rejects removing the remaining chief after another chief has lost access" do
          successor.update!(subteam: nil, role: :chief_engineer)
          patch revoke_user_path(successor)
          patch revoke_user_path(chief)

          expect(flash[:alert]).to include(required_message)
          expect(chief.reload).not_to be_access_revoked
     end

     it "allows ordinary edits to the last chief without changing their administrator access" do
          patch user_path(chief), params: { user: { role: "chief_engineer", subteam_id: "" } }

          expect(response).to redirect_to(users_path)
          expect(chief.reload.team).to be_nil
          expect(chief).to be_chief_engineer
          expect(chief).not_to be_access_revoked
     end

     it "lets a chief restore a revoked chief and then hand over access" do
          successor.update!(subteam: nil, role: :chief_engineer, access_revoked_at: Time.current)
          patch restore_user_path(successor)
          expect(successor.reload).not_to be_access_revoked

          patch revoke_user_path(chief)
          expect(chief.reload).to be_access_revoked
          get users_path
          expect(response).to redirect_to(login_path)

          sign_in(successor)
          get users_path
          expect(response).to have_http_status(:ok)
     end

     it "denies direct role and access changes from officers and members" do
          [ users(:officer), users(:member) ].each do |person|
               sign_in(person)
               patch revoke_user_path(chief)
               expect(response).to redirect_to(root_path)
               expect(chief.reload).not_to be_access_revoked

               patch user_path(person), params: { user: { role: "chief_engineer" } }
               expect(response).to redirect_to(root_path)
               expect(person.reload).not_to be_chief_engineer
          end
     end

     it "enforces the same rule on ordinary model updates outside the controller" do
          expect(chief.update(access_revoked_at: Time.current)).to be(false)
          expect(chief.errors[:base].join).to include(required_message)
          expect(chief.reload).not_to be_access_revoked
     end
end
