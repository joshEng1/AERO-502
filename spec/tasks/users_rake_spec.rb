require "rails_helper"
require "rake"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe "users:grant_chief_engineer" do
     before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

     def run_task(emails)
          ENV["EMAILS"] = emails
          Rake::Task["users:grant_chief_engineer"].reenable
          Rake::Task["users:grant_chief_engineer"].invoke
     ensure
          ENV.delete("EMAILS")
     end

     it "adds new Google-only Chief Engineers who can sign in without a password" do
          expect { run_task(" New.Dev@TAMU.edu , second.dev@tamu.edu") }
               .to change(User, :count).by(2).and output(/new\.dev@tamu\.edu: Chief Engineer \(added\)/).to_stdout

          user = User.find_by!(email: "new.dev@tamu.edu")
          expect(user).to be_chief_engineer
          expect(user.name).to eq("new.dev")
          expect(user.password_digest).to be_nil
     end

     it "promotes an existing person and restores revoked access without renaming them" do
          member = users(:officer)
          member.update_columns(access_revoked_at: Time.current)

          expect { run_task(member.email) }
               .to not_change(User, :count).and output(/Chief Engineer \(updated\)/).to_stdout
          expect(member.reload).to be_chief_engineer
          expect(member.access_revoked_at).to be_nil
          expect(member.name).to eq("Olivia Officer")
     end

     it "refuses to run without any emails" do
          expect { run_task("") }.to raise_error(SystemExit).and output(/Set EMAILS/).to_stderr
     end

     it "reports invalid emails and fails" do
          expect { run_task("not-an-email") }
               .to raise_error(SystemExit).and output(/not-an-email: Email is invalid/).to_stderr
          expect(User.find_by(email: "not-an-email")).to be_nil
     end
end
