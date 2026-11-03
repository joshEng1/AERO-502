require_relative "../../lib/sprint_three/legacy_data"

class AlignApprovedSprintThreeDesign < ActiveRecord::Migration[8.1]
     def up
          legacy = SprintThree::LegacyData.new(connection)
          legacy.validate!
          migrate_memberships(legacy)
          migrate_tasks
          migrate_history(legacy)
          create_dependencies
          install_integrity_constraints
     end

     def down
          raise ActiveRecord::IrreversibleMigration, "Restore the pre-migration backup into a separate database with its matching code; shared tasks and assignment periods cannot be collapsed losslessly."
     end

     private

     def insert_row(table, values)
          execute "INSERT INTO #{quote_table_name(table)} (#{values.keys.map { |key| quote_column_name(key) }.join(', ')}) VALUES (#{values.values.map { |value| connection.quote(value) }.join(', ')})"
     end

     def migrate_memberships(legacy)
          add_column :users, :role, :integer, null: false, default: 0
          execute "UPDATE users SET role = 2 WHERE global_role = 2"
          create_table :memberships, id: false do |t|
               t.bigint :user_id, null: false, primary_key: true
               t.references :subteam, null: false, foreign_key: true
          end
          add_foreign_key :memberships, :users
          legacy.memberships.each do |membership|
               insert_row(:memberships, membership.except(:role))
               execute "UPDATE users SET role = #{membership[:role]} WHERE id = #{membership[:user_id]}"
          end
          drop_table :subteam_memberships
          drop_table :team_memberships
          remove_column :users, :global_role
          add_check_constraint :users, "role IN (0, 1, 2)", name: "approved_user_roles"
     end

     def migrate_tasks
          add_reference :tasks, :project, foreign_key: true
          execute "UPDATE tasks SET project_id = project_subteams.project_id FROM project_subteams WHERE project_subteams.id = tasks.project_subteam_id"
          change_column_null :tasks, :project_id, false
          remove_reference :tasks, :project_subteam, foreign_key: true
          drop_table :project_subteams
          select_all("SELECT task_id, url FROM task_links ORDER BY task_id, position, id").group_by { |link| link["task_id"] }.each do |task_id, links|
               # Preserve reference text verbatim; a task's own route is generated
               # from its id in the UI and no longer stored in a separate table.
               instructions = select_value("SELECT instructions FROM tasks WHERE id = #{task_id}").to_s
               urls = links.map { |link| link["url"] }.reject { |url| instructions.include?(url) }
               next if urls.empty?

               text = instructions + "\n\nReference links:\n#{urls.join("\n")}"
               execute "UPDATE tasks SET instructions = #{connection.quote(text)} WHERE id = #{task_id}"
          end
          drop_table :task_links
     end

     def migrate_history(legacy)
          remove_index :task_assignments, %i[task_id user_id]
          add_reference :task_assignments, :assigned_by, foreign_key: { to_table: :users }
          add_reference :task_assignments, :unassigned_by, foreign_key: { to_table: :users }
          add_column :task_assignments, :assigned_at, :datetime
          add_column :task_assignments, :unassigned_at, :datetime
          add_column :task_assignments, :is_primary_contact, :boolean, default: false, null: false
          legacy.periods.each do |period|
               if period[:id]
                    columns = period.except(:id).map { |key, value| "#{quote_column_name(key)} = #{connection.quote(value)}" }.join(", ")
                    execute "UPDATE task_assignments SET #{columns} WHERE id = #{period[:id]}"
               else
                    insert_row(:task_assignments, period)
               end
          end
          change_column_null :task_assignments, :assigned_by_id, false
          change_column_null :task_assignments, :assigned_at, false
          add_index :task_assignments, %i[task_id user_id assigned_at], unique: true, name: "unique_assignment_period"
          add_index :task_assignments, %i[task_id user_id], unique: true, where: "unassigned_at IS NULL", name: "one_active_assignment"
          add_index :task_assignments, :task_id, unique: true, where: "is_primary_contact AND unassigned_at IS NULL", name: "one_primary_contact"
          add_check_constraint :task_assignments, "(unassigned_by_id IS NULL AND unassigned_at IS NULL) OR (unassigned_by_id IS NOT NULL AND unassigned_at IS NOT NULL AND unassigned_at >= assigned_at)", name: "assignment_ending_pair"
          add_check_constraint :task_assignments, "NOT is_primary_contact OR unassigned_at IS NULL", name: "primary_contact_is_active"
          create_table :task_status_changes do |t|
               t.references :task, null: false, foreign_key: true
               t.references :actor, null: false, foreign_key: { to_table: :users }
               t.integer :to_status, null: false
               t.datetime :created_at, null: false
          end
          add_index :task_status_changes, %i[task_id created_at id], name: "ordered_status_history"
          add_check_constraint :task_status_changes, "to_status IN (0, 1, 2)", name: "valid_history_status"
          legacy.statuses.each { |row| insert_row(:task_status_changes, row) }
          drop_table :task_events
     end

     def create_dependencies
          create_table :task_dependencies, id: false do |t|
               t.references :task, null: false, foreign_key: true
               t.references :prerequisite_task, null: false, foreign_key: { to_table: :tasks }
          end
          execute "ALTER TABLE task_dependencies ADD PRIMARY KEY (task_id, prerequisite_task_id)"
          add_check_constraint :task_dependencies, "task_id <> prerequisite_task_id", name: "no_self_dependency"
     end

     def install_integrity_constraints
          # One transaction lock serializes related ownership/assignment writes.
          # Deferred validation permits an atomic role/membership transfer while
          # preventing two concurrent transfers from validating stale ownership.
          execute <<~SQL
               CREATE FUNCTION aero_integrity_lock() RETURNS trigger LANGUAGE plpgsql AS $$
               BEGIN
                    PERFORM pg_advisory_xact_lock(5023001);
                    RETURN NULL;
               END $$;

               CREATE FUNCTION aero_validate_integrity() RETURNS trigger LANGUAGE plpgsql AS $$
               BEGIN
                    IF EXISTS (
                         SELECT 1 FROM users u LEFT JOIN memberships m ON m.user_id = u.id
                         WHERE (u.role = 2 AND m.user_id IS NOT NULL) OR (u.role <> 2 AND m.user_id IS NULL)
                    ) THEN RAISE EXCEPTION 'Members and officers require exactly one subteam; administrators require none.' USING ERRCODE = '23514'; END IF;
                    IF EXISTS (
                         SELECT 1 FROM task_assignments a JOIN tasks t ON t.id = a.task_id
                         JOIN projects p ON p.id = t.project_id LEFT JOIN memberships m ON m.user_id = a.user_id
                         LEFT JOIN subteams s ON s.id = m.subteam_id
                         WHERE a.unassigned_at IS NULL AND (m.user_id IS NULL OR s.team_id <> p.team_id)
                    ) THEN RAISE EXCEPTION 'An active assignee must belong to the project team; resolve assignments before transferring ownership.' USING ERRCODE = '23514'; END IF;
                    IF EXISTS (
                         SELECT 1 FROM tasks t LEFT JOIN LATERAL (
                              SELECT to_status FROM task_status_changes WHERE task_id = t.id ORDER BY created_at DESC, id DESC LIMIT 1
                         ) latest ON TRUE WHERE latest.to_status IS NULL OR latest.to_status <> t.status
                    ) THEN RAISE EXCEPTION 'Task status must match its complete status history.' USING ERRCODE = '23514'; END IF;
                    IF EXISTS (
                         SELECT 1 FROM task_dependencies d JOIN tasks t ON t.id = d.task_id JOIN projects p ON p.id = t.project_id
                         JOIN tasks r ON r.id = d.prerequisite_task_id JOIN projects q ON q.id = r.project_id WHERE p.team_id <> q.team_id
                    ) THEN RAISE EXCEPTION 'Prerequisites must stay within the same team.' USING ERRCODE = '23514'; END IF;
                    IF EXISTS (
                         WITH RECURSIVE paths(start_id, end_id) AS (
                              SELECT task_id, prerequisite_task_id FROM task_dependencies
                              UNION SELECT paths.start_id, d.prerequisite_task_id FROM paths JOIN task_dependencies d ON d.task_id = paths.end_id
                         ) SELECT 1 FROM paths WHERE start_id = end_id
                    ) THEN RAISE EXCEPTION 'Prerequisites cannot form a loop.' USING ERRCODE = '23514'; END IF;
                    RETURN NULL;
               END $$;

               CREATE FUNCTION aero_guard_status_history() RETURNS trigger LANGUAGE plpgsql AS $$
               DECLARE previous integer; previous_time timestamp;
               BEGIN
                    IF TG_OP <> 'INSERT' THEN RAISE EXCEPTION 'Status history cannot be edited or deleted.' USING ERRCODE = '23514'; END IF;
                    SELECT to_status, created_at INTO previous, previous_time FROM task_status_changes WHERE task_id = NEW.task_id ORDER BY created_at DESC, id DESC LIMIT 1;
                    IF previous = NEW.to_status THEN RAISE EXCEPTION 'The status has not changed.' USING ERRCODE = '23514'; END IF;
                    IF previous_time IS NOT NULL AND NEW.created_at < previous_time THEN
                         RAISE EXCEPTION 'A status change cannot precede the latest recorded change.' USING ERRCODE = '23514';
                    END IF;
                    IF previous IS NULL AND NOT EXISTS (
                         SELECT 1 FROM tasks WHERE id = NEW.task_id AND creator_id = NEW.actor_id AND created_at = NEW.created_at
                    ) THEN RAISE EXCEPTION 'Initial status history must identify the task creator and creation time.' USING ERRCODE = '23514'; END IF;
                    IF NOT EXISTS (
                         SELECT 1 FROM users u JOIN tasks t ON t.id = NEW.task_id JOIN projects p ON p.id = t.project_id
                         LEFT JOIN memberships m ON m.user_id = u.id LEFT JOIN subteams s ON s.id = m.subteam_id
                         WHERE u.id = NEW.actor_id AND u.access_revoked_at IS NULL AND (
                              u.role = 2 OR (u.role = 1 AND s.team_id = p.team_id) OR EXISTS (
                                   SELECT 1 FROM task_assignments a WHERE a.task_id = t.id AND a.user_id = u.id AND a.unassigned_at IS NULL
                              )
                         )
                    ) THEN RAISE EXCEPTION 'The status actor must have access to this task.' USING ERRCODE = '23514'; END IF;
                    RETURN NEW;
               END $$;
               CREATE TRIGGER immutable_status_history BEFORE INSERT OR UPDATE OR DELETE ON task_status_changes
                    FOR EACH ROW EXECUTE FUNCTION aero_guard_status_history();

               CREATE FUNCTION aero_guard_assignment_history() RETURNS trigger LANGUAGE plpgsql AS $$
               BEGIN
                    IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'Assignment periods cannot be deleted.' USING ERRCODE = '23514'; END IF;
                    IF TG_OP = 'UPDATE' THEN
                         IF (NEW.task_id, NEW.user_id, NEW.assigned_by_id, NEW.assigned_at) IS DISTINCT FROM
                            (OLD.task_id, OLD.user_id, OLD.assigned_by_id, OLD.assigned_at) THEN
                              RAISE EXCEPTION 'The beginning of an assignment period cannot be rewritten.' USING ERRCODE = '23514';
                         END IF;
                         IF OLD.unassigned_at IS NOT NULL AND (NEW.unassigned_by_id, NEW.unassigned_at) IS DISTINCT FROM
                            (OLD.unassigned_by_id, OLD.unassigned_at) THEN
                              RAISE EXCEPTION 'An ended assignment cannot be reopened or rewritten; create a new period.' USING ERRCODE = '23514';
                         END IF;
                    END IF;
                    RETURN NEW;
               END $$;
               CREATE TRIGGER immutable_assignment_history BEFORE UPDATE OR DELETE ON task_assignments
                    FOR EACH ROW EXECUTE FUNCTION aero_guard_assignment_history();
          SQL
          %w[users memberships subteams projects tasks task_assignments task_status_changes task_dependencies].each do |table|
               execute "CREATE TRIGGER lock_approved_integrity BEFORE INSERT OR UPDATE OR DELETE ON #{table} FOR EACH STATEMENT EXECUTE FUNCTION aero_integrity_lock()"
               execute "CREATE CONSTRAINT TRIGGER validate_approved_integrity AFTER INSERT OR UPDATE OR DELETE ON #{table} DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION aero_validate_integrity()"
          end
     end
end
