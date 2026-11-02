# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_23_121000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "project_subteams", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "subteam_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "project_id", "subteam_id" ], name: "index_project_subteams_on_project_id_and_subteam_id", unique: true
    t.index [ "project_id" ], name: "index_project_subteams_on_project_id"
    t.index [ "subteam_id" ], name: "index_project_subteams_on_subteam_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.bigint "team_id", null: false
    t.index "team_id, lower((name)::text)", name: "index_projects_on_team_and_normalized_name", unique: true
    t.index [ "team_id" ], name: "index_projects_on_team_id"
  end

  create_table "subteam_memberships", force: :cascade do |t|
    t.bigint "team_membership_id", null: false
    t.bigint "subteam_id", null: false
    t.datetime "joined_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "subteam_id" ], name: "index_subteam_memberships_on_subteam_id"
    t.index [ "team_membership_id", "subteam_id" ], name: "index_subteam_membership_pair", unique: true
    t.index [ "team_membership_id" ], name: "index_subteam_memberships_on_team_membership_id"
    t.check_constraint "ended_at IS NULL OR ended_at >= joined_at", name: "subteam_membership_dates"
  end

  create_table "subteams", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.index [ "team_id", "name" ], name: "index_subteams_on_team_id_and_name", unique: true
    t.index [ "team_id" ], name: "index_subteams_on_team_id"
  end

  create_table "task_assignments", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "task_id", "user_id" ], name: "index_task_assignments_on_task_id_and_user_id", unique: true
    t.index [ "task_id" ], name: "index_task_assignments_on_task_id"
    t.index [ "user_id" ], name: "index_task_assignments_on_user_id"
  end

  create_table "task_events", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "from_status"
    t.string "to_status"
    t.datetime "created_at", null: false
    t.bigint "subject_user_id"
    t.index [ "actor_id" ], name: "index_task_events_on_actor_id"
    t.index [ "subject_user_id" ], name: "index_task_events_on_subject_user_id"
    t.index [ "task_id", "created_at" ], name: "index_task_events_on_task_id_and_created_at"
    t.index [ "task_id" ], name: "index_task_events_on_task_id"
  end

  create_table "task_links", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "url", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "task_id" ], name: "index_task_links_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.text "instructions"
    t.date "due_date", null: false
    t.decimal "estimated_hours", precision: 7, scale: 2, null: false
    t.integer "status", default: 0, null: false
    t.bigint "creator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date", null: false
    t.bigint "project_subteam_id", null: false
    t.index [ "creator_id" ], name: "index_tasks_on_creator_id"
    t.index [ "project_subteam_id" ], name: "index_tasks_on_project_subteam_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "team_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "joined_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "team_id" ], name: "index_team_memberships_on_team_id"
    t.index [ "user_id", "team_id" ], name: "index_team_memberships_on_user_id_and_team_id", unique: true
    t.index [ "user_id" ], name: "index_team_memberships_on_user_id"
    t.check_constraint "ended_at IS NULL OR ended_at >= joined_at", name: "team_membership_dates"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.index [ "name" ], name: "index_teams_on_name", unique: true
  end

  create_table "time_entries", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.decimal "hours", precision: 7, scale: 2, null: false
    t.string "note"
    t.date "worked_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "task_id" ], name: "index_time_entries_on_task_id"
    t.index [ "user_id" ], name: "index_time_entries_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.integer "global_role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "access_revoked_at"
    t.index [ "email" ], name: "index_users_on_email", unique: true
  end

  add_foreign_key "project_subteams", "projects"
  add_foreign_key "project_subteams", "subteams"
  add_foreign_key "projects", "teams"
  add_foreign_key "subteam_memberships", "subteams"
  add_foreign_key "subteam_memberships", "team_memberships"
  add_foreign_key "subteams", "teams"
  add_foreign_key "task_assignments", "tasks"
  add_foreign_key "task_assignments", "users"
  add_foreign_key "task_events", "tasks"
  add_foreign_key "task_events", "users", column: "actor_id"
  add_foreign_key "task_events", "users", column: "subject_user_id"
  add_foreign_key "task_links", "tasks"
  add_foreign_key "tasks", "project_subteams"
  add_foreign_key "tasks", "users", column: "creator_id"
  add_foreign_key "team_memberships", "teams"
  add_foreign_key "team_memberships", "users"
  add_foreign_key "time_entries", "tasks"
  add_foreign_key "time_entries", "users"
end
