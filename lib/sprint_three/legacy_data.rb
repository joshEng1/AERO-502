module SprintThree
     # Reads the previous schema without loading application models. Missing
     # historical facts must be reconciled from evidence, never invented here.
     class LegacyData
          STATUSES = { "backlog" => 0, "in_progress" => 1, "completed" => 2 }.freeze
          attr_reader :connection, :errors, :memberships, :periods, :statuses

          def initialize(connection)
               @connection = connection
               @errors, @memberships, @periods, @statuses = [], [], [], []
               read_memberships
               read_history
               check_assignment_eligibility
          end

          def validate!
               return if errors.empty?

               raise ActiveRecord::MigrationError, "Sprint 3 preflight failed; reconcile these records from reliable evidence and rerun:\n#{errors.join("\n")}"
          end

          def report
               { ready: errors.empty?, memberships: memberships.size, assignment_periods: periods.size,
                 status_changes: statuses.size, problems: errors }
          end

          private

          def rows(sql)
               connection.select_all(sql).to_a
          end

          def read_memberships
               people = rows("SELECT id, global_role FROM users")
               teams = rows("SELECT * FROM team_memberships WHERE ended_at IS NULL").group_by { |r| r["user_id"] }
               subteams = rows(<<~SQL).group_by { |r| r["team_membership_id"] }
                    SELECT sm.*, s.team_id FROM subteam_memberships sm
                    JOIN subteams s ON s.id = sm.subteam_id WHERE sm.ended_at IS NULL
               SQL
               people.each do |person|
                    active = teams.fetch(person["id"], [])
                    if person["global_role"] == 2
                         errors << "Administrator user #{person['id']} still has an active membership." if active.any?
                         next
                    end
                    unless active.one? && subteams.fetch(active.first["id"], []).one?
                         errors << "User #{person['id']} needs exactly one active class/subteam membership."
                         next
                    end
                    parent = active.first
                    child = subteams.fetch(parent["id"]).first
                    unless child["team_id"] == parent["team_id"] && [ 0, 1 ].include?(parent["role"])
                         errors << "User #{person['id']} has inconsistent class membership or role."
                         next
                    end
                    memberships << { user_id: person["id"], subteam_id: child["subteam_id"], role: parent["role"] }
               end
          end

          def read_history
               tasks = rows("SELECT * FROM tasks ORDER BY id")
               events = rows("SELECT * FROM task_events ORDER BY created_at, id")
               events.each do |event|
                    errors << "Task event #{event['id']} is missing its actor." unless event["actor_id"]
                    unless %w[assigned unassigned status_changed].include?(event["action"])
                         errors << "Task event #{event['id']} has an unrecognized action."
                    end
               end
               changes = events.select { |e| e["action"] == "status_changed" }.group_by { |e| e["task_id"] }
               tasks.each { |task| read_statuses(task, changes.fetch(task["id"], [])) }
               assignment_events = events.select { |e| %w[assigned unassigned].include?(e["action"]) }
               assignment_events.each do |event|
                    errors << "Task event #{event['id']} is missing its assignee." unless event["subject_user_id"]
               end
               current = rows("SELECT * FROM task_assignments").index_by { |r| [ r["task_id"], r["user_id"] ] }
               groups = assignment_events.group_by { |e| [ e["task_id"], e["subject_user_id"] ] }
               (current.keys | groups.keys).each do |key|
                    read_periods(key, groups.fetch(key, []), current[key])
               end
          end

          def read_statuses(task, events)
               initial = events.any? ? STATUSES[events.first["from_status"]] : task["status"]
               unless initial && task["creator_id"]
                    errors << "Task #{task['id']} has no reliable initial status or creator."
                    return
               end
               statuses << { task_id: task["id"], actor_id: task["creator_id"], to_status: initial, created_at: task["created_at"] }
               previous = initial
               events.each do |event|
                    target = STATUSES[event["to_status"]]
                    unless target && STATUSES[event["from_status"]] == previous && target != previous && event["created_at"] >= task["created_at"]
                         errors << "Task event #{event['id']} has inconsistent status history."
                         next
                    end
                    statuses << { task_id: task["id"], actor_id: event["actor_id"], to_status: target, created_at: event["created_at"] }
                    previous = target
               end
               errors << "Task #{task['id']} status differs from its latest recorded change." unless previous == task["status"]
          end

          def read_periods(key, events, existing)
               active = nil
               events.each do |event|
                    if event["action"] == "assigned"
                         if active
                              errors << "Task event #{event['id']} starts an already-active assignment."
                              next
                         end
                         active = { task_id: key[0], user_id: key[1], assigned_by_id: event["actor_id"],
                                    assigned_at: event["created_at"], created_at: event["created_at"], updated_at: event["created_at"] }
                    elsif active
                         active.merge!(unassigned_by_id: event["actor_id"], unassigned_at: event["created_at"], updated_at: event["created_at"])
                         periods << active
                         active = nil
                    else
                         errors << "Task event #{event['id']} ends an assignment with no recorded beginning."
                    end
               end
               if active && existing
                    periods << active.merge(id: existing["id"], created_at: existing["created_at"], updated_at: existing["updated_at"])
               elsif active || existing
                    errors << "Task #{key[0]}, user #{key[1]}: current assignment and assignment history disagree (missing assigner/time or missing active row)."
               end
               duplicates = periods.select { |p| [ p[:task_id], p[:user_id] ] == key }.group_by { |p| p[:assigned_at] }
               errors << "Task #{key[0]}, user #{key[1]}: assignment start times are not unique." if duplicates.any? { |_, p| p.size > 1 }
          end

          def check_assignment_eligibility
               team_by_subteam = rows("SELECT id, team_id FROM subteams").to_h { |r| [ r["id"], r["team_id"] ] }
               member_teams = memberships.to_h { |r| [ r[:user_id], team_by_subteam[r[:subteam_id]] ] }
               task_teams = rows(<<~SQL).to_h { |r| [ r["id"], r["team_id"] ] }
                    SELECT t.id, p.team_id FROM tasks t
                    JOIN project_subteams ps ON ps.id = t.project_subteam_id JOIN projects p ON p.id = ps.project_id
               SQL
               periods.reject { |p| p[:unassigned_at] }.each do |period|
                    unless member_teams[period[:user_id]] && member_teams[period[:user_id]] == task_teams[period[:task_id]]
                         errors << "Task #{period[:task_id]}, user #{period[:user_id]}: active assignment crosses the approved team boundary."
                    end
               end
          end
     end
end
