require "rails_helper"

RSpec.describe "Sprint 3 assignment and ownership boundaries" do
     it "rejects ineligible assignees and partially ended or primary ended periods" do
          [ users(:chief), users(:other_member) ].each do |person|
               assignment = TaskAssignment.new(task: tasks(:wing_test), user: person, assigned_by: users(:chief), assigned_at: Time.current)
               expect(assignment).not_to be_valid
               expect(assignment.errors[:user]).to be_present
          end
          assignment = task_assignments(:wing_member)
          assignment.unassigned_by = users(:chief)
          expect(assignment).not_to be_valid
          assignment.unassigned_at = assignment.assigned_at - 1.second
          expect(assignment).not_to be_valid
          assignment.unassigned_at = Time.current
          assignment.is_primary_contact = true
          expect(assignment).not_to be_valid
          expect(assignment.errors[:is_primary_contact]).to be_present
     end

     it "allows clearing a primary contact without ending the assignment" do
          task = tasks(:wing_test)
          task.designate_primary_contact(users(:member).id)
          expect(task.primary_contact).to eq(users(:member))
          task.designate_primary_contact("")
          expect(task.primary_contact).to be_nil
          expect(task.assignee_ids).to eq([ users(:member).id ])
     end

     it "permits empty ownership moves while rejecting unresolved assignments and dependencies" do
          empty = Subteam.create!(name: "Unstaffed", team: teams(:aerodynamics))
          empty.update!(team: teams(:structures))
          expect(empty.reload.team).to eq(teams(:structures))
          project = projects(:archive)
          project.update!(team: teams(:structures))
          expect(project.reload.team).to eq(teams(:structures))
          task = tasks(:wing_test)
          expect(task.update(project: project)).to be(false)
          expect(task.errors[:project]).to include("would invalidate active assignments")
          task.reload
          prerequisite = Task.create!(title: "Design review", project: projects(:aero), creator: users(:chief), due_date: Date.current + 1, estimated_hours: 0)
          task.replace_prerequisites([ prerequisite.id ], actor: users(:chief))
          same_team = Project.create!(name: "Same class", team: teams(:aerodynamics))
          task.update!(project: same_team)
          expect(task.prerequisites).to include(prerequisite)
          expect(task.update(project: project)).to be(false)
          expect(task.errors[:project]).to include("cannot move to another team while prerequisites are linked")
          expect(projects(:aero).update(team: teams(:structures))).to be(false)
          expect(projects(:aero).errors[:team]).to include("cannot change while tasks have prerequisites; resolve the links first")
     end

     it "rejects missing and cross-team prerequisites and inconsistent class hints" do
          expect(TaskDependency.new).not_to be_valid
          dependency = TaskDependency.new(task: tasks(:wing_test), prerequisite_task: tasks(:spar_check))
          expect(dependency).not_to be_valid
          expect(dependency.errors[:prerequisite_task]).to include("must belong to the same team")
          person = User.new(name: "New member", email: "new@tamu.edu", role: :member, subteam: subteams(:wing), team_id: teams(:structures).id)
          expect(person).not_to be_valid
          expect(person.errors[:subteam]).to include("must belong to the person's team")
          person.team_id = ""
          expect(person).to be_valid
     end

     it "retains historical contributors in a task summary even after unassignment" do
          task = tasks(:wing_test)
          task.assign_members([], actor: users(:chief))
          summary = HourSummary.new(tasks: [ task ])
          expect(summary.member_rows.map(&:member)).to eq([ users(:member) ])
          expect(summary.member_rows.first.actual).to eq(2.5)
          expect(summary.member_rows.first.estimate).to eq(0)
          expect(summary.total_estimate).to eq(10)
     end
end
