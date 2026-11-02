# AERO Task Hub

A Vivify Scrum-style, role-aware task and effort tracker for the SAE AERO Design team. The application provides approved Google access, shared team-level projects, subteam rosters, task assignments and status updates, dated hour logging, a schedule timeline, and filtered CSV reports.

## Capabilities

- Chief Engineers can view and manage every team's work.
- Officers can create, assign, and edit tasks only for their own team.
- Members can see only assigned work, update its status, and log their own hours.
- Task cards capture deliverables, work instructions, links, due dates, estimates, status, and multiple assignees.
- Dashboards show assignments, statuses, estimated hours, actual hours, variance, and member totals.
- Projects belong to one class (team) and are available to all its subteams. A task appears on the boards of its active assignees' subteams, with the same task ID on each board.
- Members and officers have exactly one subteam membership; Chief Engineers have none. Assignment periods and initial/status history are retained.
- Leaders can create tasks from empty board columns, search eligible assignees, select a primary contact, and link prerequisites with visible blockers.
- Leaders maintain rosters independently of assignments, including members with no work or recorded hours.
- Task, timeline, member-hour and project-hour CSV downloads follow the same access rules and filters as the website.
- Server-side authorization protects direct URLs as well as navigation.

## Local setup

Requirements: Ruby 4.0.6, Rails 8.1, PostgreSQL 16, and Bundler 4.0.16. Browser tests also require Chrome/Chromium and a compatible ChromeDriver (Selenium Manager can locate them).

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```

Open http://localhost:3000. The practice password defaults to `AeroSprint1!` and can be overridden with `DEMO_PASSWORD`. Practice emails are listed in `docs/TRAINING_GUIDE.md`.

## Verification

```sh
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
```

SimpleCov enforces 100% line and branch coverage. GitHub Actions runs RSpec with PostgreSQL 16, RuboCop, Brakeman, and the import-map audit. The concurrent ownership test needs independent PostgreSQL sessions; single-session emulators cannot validate it.

The schema is stored in `db/structure.sql` to preserve deferred constraints and history triggers. For an existing database, run `bin/rails sprint3:preflight` on an isolated restored copy before migrating. Follow the administrator guide; this migration has no lossless automatic rollback.

## Documentation

- [User guide](docs/USER_GUIDE.md)
- [Administration, update, and recovery](docs/ADMIN_GUIDE.md)
- [Deployment guide](docs/DEPLOYMENT.md)
- [Training checklist](docs/TRAINING_GUIDE.md)
- [Sprint 1 traceability and evidence](docs/SPRINT1_EVIDENCE.md)
- [Five-aspect quality strategy](docs/QUALITY_STRATEGY.md)
- [Verification results](docs/VERIFICATION.md)
- [Sprint 3 stories and migration verification](docs/SPRINT3_STORIES_VERIFICATION.md)
- [Sprint 3 operational handover record](docs/SPRINT3_HANDOVER.md)
- [Offline restart PDF](docs/RESTART_GUIDE.pdf)
- [Canvas submission checklist](docs/SUBMISSION_CHECKLIST.md)
