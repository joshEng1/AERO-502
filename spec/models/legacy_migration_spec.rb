require "rails_helper"
require Rails.root.join("db/migrate/20261102000000_align_approved_sprint_three_design")

RSpec.describe "Approved Sprint 3 migration" do
     let(:connection) { ApplicationRecord.connection }

     around do |example|
          original_path = connection.schema_search_path
          original_verbose = ActiveRecord::Migration.verbose
          connection.transaction(requires_new: true) do
               connection.execute("CREATE SCHEMA legacy_sprint_three")
               connection.schema_search_path = "legacy_sprint_three"
               connection.schema_cache.clear!
               ActiveRecord::Migration.verbose = false
               load Rails.root.join("spec/fixtures/legacy_schema.rb")
               seed_legacy_records
               example.run
               raise ActiveRecord::Rollback
          end
     ensure
          ActiveRecord::Migration.verbose = original_verbose
          connection.schema_search_path = original_path
          connection.schema_cache.clear!
     end

     def insert(table, values)
          values = { created_at: "2026-09-01 12:00:00", updated_at: "2026-09-01 12:00:00" }.merge(values)
          values.delete(:updated_at) if table == "task_events"
          connection.execute("INSERT INTO #{table} (#{values.keys.join(',')}) VALUES (#{values.values.map { |value| connection.quote(value) }.join(',')})")
     end

     def seed_legacy_records
          insert("teams", id: 1, name: "Regular")
          insert("subteams", id: 2, name: "Wing", team_id: 1)
          insert("projects", id: 3, name: "Aircraft", team_id: 1)
          insert("project_subteams", id: 4, project_id: 3, subteam_id: 2)
          insert("users", id: 5, name: "Chief", email: "chief@tamu.edu", global_role: 2)
          insert("users", id: 6, name: "Member", email: "member@tamu.edu", global_role: 0)
          insert("users", id: 7, name: "Officer", email: "officer@tamu.edu", global_role: 0)
          insert("team_memberships", id: 8, user_id: 6, team_id: 1, role: 0, joined_at: "2026-09-01 12:00:00")
          insert("team_memberships", id: 9, user_id: 7, team_id: 1, role: 1, joined_at: "2026-09-01 12:00:00")
          insert("subteam_memberships", id: 10, team_membership_id: 8, subteam_id: 2, joined_at: "2026-09-01 12:00:00")
          insert("subteam_memberships", id: 11, team_membership_id: 9, subteam_id: 2, joined_at: "2026-09-01 12:00:00")
          insert("tasks", id: 12, project_subteam_id: 4, creator_id: 7, title: "Wing test", status: 1,
                 start_date: "2026-09-01", due_date: "2026-09-05", estimated_hours: 5, instructions: "Use the approved fixture.")
          insert("task_events", id: 13, task_id: 12, actor_id: 7, action: "assigned", subject_user_id: 6, created_at: "2026-09-01 13:00:00")
          insert("task_events", id: 14, task_id: 12, actor_id: 6, action: "status_changed", from_status: "backlog", to_status: "in_progress", created_at: "2026-09-02 13:00:00")
          insert("task_events", id: 15, task_id: 12, actor_id: 5, action: "unassigned", subject_user_id: 6, created_at: "2026-09-03 13:00:00")
          insert("task_events", id: 16, task_id: 12, actor_id: 7, action: "assigned", subject_user_id: 6, created_at: "2026-09-04 13:00:00")
          insert("task_assignments", id: 17, task_id: 12, user_id: 6, created_at: "2026-09-04 13:00:00")
          insert("task_links", id: 18, task_id: 12, url: "https://example.com/wing", position: 0)
          insert("time_entries", id: 19, task_id: 12, user_id: 6, hours: 2.5, worked_on: "2026-09-02")
     end

     it "converts real history into periods and ordered statuses without losing IDs, actors, hours or reference links" do
          report = SprintThree::LegacyData.new(connection).report
          expect(report).to include(ready: true, assignment_periods: 2, status_changes: 2, memberships: 2)
          AlignApprovedSprintThreeDesign.new.migrate(:up)
          expect(connection.select_rows("SELECT user_id, subteam_id FROM memberships ORDER BY user_id")).to eq([ [ 6, 2 ], [ 7, 2 ] ])
          expect(connection.select_rows("SELECT id, role FROM users ORDER BY id")).to eq([ [ 5, 2 ], [ 6, 0 ], [ 7, 1 ] ])
          expect(connection.select_value("SELECT project_id FROM tasks WHERE id = 12")).to eq(3)
          expect(connection.select_value("SELECT instructions FROM tasks WHERE id = 12")).to include("Use the approved fixture.", "https://example.com/wing")
          expect(connection.select_value("SELECT SUM(hours) FROM time_entries")).to eq(2.5)
          expect(connection.select_value("SELECT assigned_by_id FROM task_assignments WHERE id = 17")).to eq(7)
          expect(connection.select_rows("SELECT assigned_by_id, unassigned_by_id FROM task_assignments ORDER BY assigned_at")).to eq([ [ 7, 5 ], [ 7, nil ] ])
          expect(connection.select_rows("SELECT actor_id, to_status FROM task_status_changes ORDER BY created_at, id")).to eq([ [ 7, 0 ], [ 6, 1 ] ])
          expect(connection.data_sources).not_to include("task_links", "task_events", "project_subteams", "team_memberships", "subteam_memberships")
          connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
     end

     it "stops before changing tables when an actor is missing, rather than inventing attribution" do
          connection.execute("UPDATE task_events SET actor_id = NULL WHERE id = 14")
          expect { AlignApprovedSprintThreeDesign.new.migrate(:up) }.to raise_error(ActiveRecord::MigrationError, /missing its actor/)
          expect(connection.table_exists?(:task_events)).to be(true)
          expect(connection.table_exists?(:memberships)).to be(false)
          expect(connection.select_value("SELECT COUNT(*) FROM task_events")).to eq(4)
     end

     it "reports incomplete memberships and unknown history instead of silently discarding them" do
          connection.execute("DELETE FROM subteam_memberships WHERE id = 10")
          connection.execute("UPDATE task_events SET action = 'unknown' WHERE id = 14")
          problems = SprintThree::LegacyData.new(connection).errors.join(" ")
          expect(problems).to include("exactly one active class/subteam", "unrecognized action", "active assignment crosses")
     end

     it "reports inconsistent status chains and active assignment rows" do
          connection.execute("UPDATE task_events SET from_status = 'in_progress' WHERE id = 14")
          connection.execute("DELETE FROM task_events WHERE id = 16")
          problems = SprintThree::LegacyData.new(connection).errors.join(" ")
          expect(problems).to include("inconsistent status history", "current assignment and assignment history disagree")
     end

     it "refuses lossy rollback instructions" do
          expect { AlignApprovedSprintThreeDesign.new.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration, /pre-migration backup/)
     end

     it "reports administrator memberships and conflicting parent classes" do
          insert("team_memberships", id: 20, user_id: 5, team_id: 1, role: 0, joined_at: "2026-09-01 12:00:00")
          insert("teams", id: 21, name: "Advanced")
          connection.execute("UPDATE team_memberships SET team_id = 21 WHERE id = 8")
          expect(SprintThree::LegacyData.new(connection).errors.join(" ")).to include("Administrator user 5", "inconsistent class membership or role")
     end

     it "requires a reliable initial status and agreement with the task's final status" do
          connection.execute("UPDATE task_events SET from_status = NULL WHERE id = 14")
          expect(SprintThree::LegacyData.new(connection).errors.join(" ")).to include("no reliable initial status or creator")
          connection.execute("UPDATE task_events SET from_status = 'backlog' WHERE id = 14")
          connection.execute("UPDATE tasks SET status = 2 WHERE id = 12")
          expect(SprintThree::LegacyData.new(connection).errors.join(" ")).to include("differs from its latest recorded change")
     end

     it "reports missing assignees, overlapping periods and endings without beginnings" do
          insert("task_events", id: 20, task_id: 12, actor_id: 7, action: "assigned", subject_user_id: 6, created_at: "2026-09-02 12:00:00")
          expect(SprintThree::LegacyData.new(connection).errors.join(" ")).to include("already-active assignment")
          connection.execute("DELETE FROM task_events WHERE id IN (13, 20)")
          connection.execute("UPDATE task_events SET subject_user_id = NULL WHERE id = 16")
          expect(SprintThree::LegacyData.new(connection).errors.join(" ")).to include("missing its assignee", "no recorded beginning")
     end

     it "preserves fully ended assignments and rejects duplicate period start times" do
          connection.execute("UPDATE task_events SET created_at = '2026-09-01 13:00:00' WHERE id IN (15, 16)")
          expect(SprintThree::LegacyData.new(connection).errors.join(" ")).to include("assignment start times are not unique")
          connection.execute("DELETE FROM task_events WHERE id = 16")
          connection.execute("DELETE FROM task_assignments WHERE id = 17")
          review = SprintThree::LegacyData.new(connection)
          expect(review.report).to include(ready: true, assignment_periods: 1)
          expect(review.periods.first).to include(unassigned_by_id: 5)
     end

     it "provides a read-only preflight command that fails when reconciliation is needed" do
          require "rake"
          Rails.application.load_tasks if Rake::Task.tasks.empty?
          task = Rake::Task["sprint3:preflight"]
          task.reenable
          expect { task.invoke }.to output(/"ready": true/).to_stdout
          connection.execute("UPDATE task_events SET actor_id = NULL WHERE id = 14")
          task.reenable
          expect { task.invoke }.to raise_error(SystemExit).and output(/Reconcile the listed records/).to_stderr.and output(/"ready": false/).to_stdout
          expect(connection.select_value("SELECT COUNT(*) FROM task_events")).to eq(4)
     end
end
