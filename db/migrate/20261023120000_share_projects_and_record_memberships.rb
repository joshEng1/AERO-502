class ShareProjectsAndRecordMemberships < ActiveRecord::Migration[8.1]
     def up
          # Refuse ambiguous legacy ownership rather than silently merging projects.
          inconsistent = select_value(<<~SQL)
               SELECT COUNT(*) FROM tasks t JOIN projects p ON p.id = t.project_id
               JOIN subteams s ON s.id = p.subteam_id
               WHERE t.subteam_id <> p.subteam_id OR t.team_id <> s.team_id
          SQL
          raise "Resolve inconsistent task ownership before migrating" if inconsistent.to_i.positive?
          duplicates = select_value(<<~SQL)
               SELECT COUNT(*) FROM (SELECT s.team_id, LOWER(p.name) FROM projects p
               JOIN subteams s ON s.id = p.subteam_id GROUP BY s.team_id, LOWER(p.name) HAVING COUNT(*) > 1) conflicts
          SQL
          raise "Resolve duplicate project names within a team before migrating" if duplicates.to_i.positive?

          add_reference :projects, :team, foreign_key: true
          execute "UPDATE projects SET team_id = subteams.team_id FROM subteams WHERE subteams.id = projects.subteam_id"
          change_column_null :projects, :team_id, false
          create_table :project_subteams do |t|
               t.references :project, null: false, foreign_key: true
               t.references :subteam, null: false, foreign_key: true
               t.timestamps
          end
          add_index :project_subteams, %i[project_id subteam_id], unique: true
          execute "INSERT INTO project_subteams (project_id, subteam_id, created_at, updated_at) SELECT id, subteam_id, created_at, updated_at FROM projects"
          add_reference :tasks, :project_subteam, foreign_key: true
          execute "UPDATE tasks SET project_subteam_id = project_subteams.id FROM project_subteams WHERE project_subteams.project_id = tasks.project_id AND project_subteams.subteam_id = tasks.subteam_id"
          change_column_null :tasks, :project_subteam_id, false
          remove_reference :tasks, :project, foreign_key: true
          remove_reference :tasks, :team, foreign_key: true
          remove_reference :tasks, :subteam, foreign_key: true
          remove_reference :projects, :subteam, foreign_key: true
          add_index :projects, "team_id, LOWER(name)", unique: true, name: "index_projects_on_team_and_normalized_name"

          create_table :team_memberships do |t|
               t.references :user, null: false, foreign_key: true
               t.references :team, null: false, foreign_key: true
               t.integer :role, null: false, default: 0
               t.datetime :joined_at, null: false
               t.datetime :ended_at
               t.timestamps
          end
          add_index :team_memberships, %i[user_id team_id], unique: true
          add_check_constraint :team_memberships, "ended_at IS NULL OR ended_at >= joined_at", name: "team_membership_dates"
          create_table :subteam_memberships do |t|
               t.references :team_membership, null: false, foreign_key: true
               t.references :subteam, null: false, foreign_key: true
               t.datetime :joined_at, null: false
               t.datetime :ended_at
               t.timestamps
          end
          add_index :subteam_memberships, %i[team_membership_id subteam_id], unique: true, name: "index_subteam_membership_pair"
          add_check_constraint :subteam_memberships, "ended_at IS NULL OR ended_at >= joined_at", name: "subteam_membership_dates"
          execute <<~SQL
               INSERT INTO team_memberships (user_id, team_id, role, joined_at, created_at, updated_at)
               SELECT id, team_id, CASE WHEN role = 1 THEN 1 ELSE 0 END, created_at, created_at, updated_at FROM users WHERE team_id IS NOT NULL
          SQL
          execute <<~SQL
               INSERT INTO subteam_memberships (team_membership_id, subteam_id, joined_at, created_at, updated_at)
               SELECT tm.id, u.subteam_id, u.created_at, u.created_at, u.updated_at FROM users u
               JOIN team_memberships tm ON tm.user_id = u.id AND tm.team_id = u.team_id WHERE u.subteam_id IS NOT NULL
          SQL
     end

     def down
          raise ActiveRecord::IrreversibleMigration, "Restore the pre-update backup; shared projects cannot be reduced to one subteam without a data decision."
     end
end
