require "rails_helper"
require "timeout"

# Requires independent PostgreSQL sessions. A single-session emulator cannot
# establish concurrency safety; CI runs this against the PostgreSQL 16 service.
RSpec.describe "Concurrent ownership transfers", :postgres_concurrency do
     self.use_transactional_tests = false

     it "serializes direct writes and rejects a transfer invalidated by the earlier commit" do
          member = users(:member)
          task = tasks(:wing_test)
          original_subteam_id = member.subteam_id
          original_project_id = task.project_id
          destination = Subteam.create!(name: "Concurrent transfer destination", team: teams(:structures))
          original_team_id = teams(:aerodynamics).id
          connections = 2.times.map { PG.connect(ApplicationRecord.connection.raw_connection.conninfo_hash) }
          first, second = connections
          second_pid = second.backend_pid
          second.exec("SET lock_timeout = '15s'")
          first.exec("BEGIN")
          first.exec_params("UPDATE memberships SET subteam_id = $1 WHERE user_id = $2", [ destination.id, member.id ])
          first.exec_params("UPDATE tasks SET project_id = $1 WHERE id = $2", [ projects(:airframe_build).id, task.id ])
          result = Queue.new
          worker = Thread.new do
               second.exec("BEGIN")
               second.exec_params("UPDATE subteams SET team_id = $1 WHERE id = $2", [ original_team_id, destination.id ])
               second.exec("COMMIT")
               result << :committed
          rescue PG::CheckViolation => error
               second.exec("ROLLBACK")
               result << error.message
          rescue StandardError => error
               second.exec("ROLLBACK")
               result << error
          end
          Timeout.timeout(10) do
               loop do
                    first.exec("SELECT pg_stat_clear_snapshot()")
                    wait = first.exec_params("SELECT wait_event FROM pg_stat_activity WHERE pid = $1", [ second_pid ]).getvalue(0, 0)
                    break if wait == "advisory"
                    sleep 0.02
               end
          end
          first.exec("COMMIT")
          expect(Timeout.timeout(10) { result.pop }).to match(/active assignee must belong to the project team/)
          expect(member.reload.subteam_id).to eq(destination.id)
          expect(task.reload.project_id).to eq(projects(:airframe_build).id)
          expect(destination.reload.team).to eq(teams(:structures))
     ensure
          # Release locks before joining, even when an expectation fails.
          first.exec("ROLLBACK") if first && !first.finished? && first.transaction_status != PG::PQTRANS_IDLE
          worker&.join(20)
          connections&.each { |connection| connection.close unless connection.finished? }
          if destination&.persisted?
               ApplicationRecord.transaction do
                    Membership.where(user_id: member.id).update_all(subteam_id: original_subteam_id)
                    Task.where(id: task.id).update_all(project_id: original_project_id)
                    destination.destroy!
               end
          end
     end
end
