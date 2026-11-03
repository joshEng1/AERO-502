require "rails_helper"

RSpec.describe "Approved organization membership integrity" do
     def reject_database_change(&block)
          expect do
               ApplicationRecord.transaction(requires_new: true) do
                    block.call
                    ApplicationRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
               end
          end.to raise_error(ActiveRecord::StatementInvalid)
     end

     it "stores one mandatory membership for members and officers and none for administrators" do
          expect(Membership.primary_key).to eq("user_id")
          expect(Membership.columns).to all(have_attributes(null: false))
          expect(User.column_names).to include("role")
          expect(User.column_names).not_to include("team_id", "subteam_id", "global_role")
          expect(users(:chief).membership).to be_nil
          expect(users(:officer).membership.subteam).to eq(subteams(:wing))
          expect(User.new(name: "Missing", email: "missing@tamu.edu", role: :member)).not_to be_valid
          expect(User.new(name: "Admin", email: "admin@tamu.edu", role: :chief_engineer, subteam: subteams(:wing))).not_to be_valid
          expect(Membership.new).not_to be_valid
          expect(Membership.new(user: users(:chief), subteam: subteams(:wing))).not_to be_valid
          expect(Membership.new(user: users(:member), subteam: subteams(:wing))).not_to be_valid
     end

     it "allows projects to exist with no tasks and share all subteams of one team" do
          second = Subteam.create!(name: "Propulsion", team: teams(:aerodynamics))
          project = Project.create!(name: "Shared goal", team: teams(:aerodynamics))
          expect(project.subteams).to contain_exactly(subteams(:wing), second)
          expect(project.tasks).to be_empty
          expect(Project.new).not_to be_valid
          expect(Subteam.new).not_to be_valid
     end

     it "transfers membership inside the class while keeping task IDs and hours" do
          person = users(:member)
          second = Subteam.create!(name: "Propulsion", team: teams(:aerodynamics))
          expect { person.update!(subteam: second) }.not_to change(Membership, :count)
          expect(person.reload.team).to eq(teams(:aerodynamics))
          expect(person.assigned_task_ids).to eq([ tasks(:wing_test).id ])
          expect(person.time_entries.sum(:hours)).to eq(2.5)
          expect(tasks(:wing_test).subteams).to contain_exactly(second)
     end

     it "requires resolving active assignments before moving between teams or promoting to administrator" do
          person = users(:member)
          expect(person.update(subteam: subteams(:airframe))).to be_falsey
          expect(person.reload.subteam).to eq(subteams(:wing))
          tasks(:wing_test).assign_members([], actor: users(:chief))
          person.update!(role: :chief_engineer, subteam: nil)
          expect(person.reload.membership).to be_nil
          expect(person.task_assignments.count).to eq(1)
          expect(person.time_entries.sum(:hours)).to eq(2.5)
     end

     it "validates required membership at transaction end even for direct SQL" do
          reject_database_change { Membership.where(user: users(:officer)).delete_all }
          reject_database_change { users(:member).update_columns(role: 2) }
          reject_database_change { Membership.insert_all!([ { user_id: users(:chief).id, subteam_id: subteams(:wing).id } ]) }
          ApplicationRecord.transaction(requires_new: true) do
               users(:officer).update_columns(role: 2)
               Membership.where(user: users(:officer)).delete_all
               ApplicationRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
          end
          expect(users(:officer).reload).to be_chief_engineer
     end

     it "rechecks eligibility across every source of team ownership on direct writes" do
          reject_database_change { memberships(:member).update_columns(subteam_id: subteams(:airframe).id) }
          reject_database_change { projects(:aero).update_columns(team_id: teams(:structures).id) }
          reject_database_change { subteams(:wing).update_columns(team_id: teams(:structures).id) }
          reject_database_change { tasks(:wing_test).update_columns(project_id: projects(:airframe_build).id) }
          reject_database_change { TaskAssignment.new(task: tasks(:wing_test), user: users(:chief), assigned_by: users(:chief), assigned_at: Time.current).save!(validate: false) }
     end

     it "rejects invalid roles and incompatible application-level ownership changes" do
          person = users(:member)
          person.role = "unknown"
          expect(person).not_to be_valid
          expect(person.errors[:role]).to be_present
          expect(projects(:aero).update(team: teams(:structures))).to be_falsey
          expect(subteams(:wing).update(team: teams(:structures))).to be_falsey
          expect(memberships(:member).update(subteam: subteams(:airframe))).to be_falsey
     end
end
