require "digest"
require "json"

# Read-only checksums let administrators compare a frozen source with its
# isolated restored copy without putting member details in verification logs.
class RecoveryManifest
     TABLE_KEYS = {
          "teams" => "id", "subteams" => "id", "projects" => "id", "users" => "id",
          "memberships" => "user_id", "tasks" => "id", "task_assignments" => "id",
          "time_entries" => "id", "task_status_changes" => "id",
          "task_dependencies" => "task_id, prerequisite_task_id"
     }.freeze

     def self.capture(connection)
          tables = TABLE_KEYS.to_h do |table, keys|
               rows = connection.select_all("SELECT * FROM #{table} ORDER BY #{keys}").to_a
               [ table, { count: rows.length, sha256: Digest::SHA256.hexdigest(JSON.generate(rows)) } ]
          end
          { tables: tables, total_actual_hours: connection.select_value("SELECT COALESCE(SUM(hours), 0) FROM time_entries").to_d.to_s("F") }
     end
end
