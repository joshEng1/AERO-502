# Sprint 3 approved design and verification

Implementation branch: `codex/sprint-3-approved-design`, based on `dev` commit `4b07387`. The approved Project Notebook v3 (Revision 6, Appendix B and Appendix D) and User Acceptance Test Form v3 control the implementation; Jira follows those sources. Approved prerequisite work adds the two-column TASK_DEPENDENCIES table to the nine-table baseline. Optional backlog items and calculated critical-path scheduling are excluded.

This record supersedes the provisional design described in the [October 23 historical verification record](archive/SPRINT3_VERIFICATION_2026-10-23.md). That earlier evidence is preserved as history; its data model and crossed Jira labels do not describe this branch.

## Approved data design

- Ten application tables and sixteen foreign keys, with SQL schema dumps retaining database functions and deferred constraints.
- PROJECTS belongs to TEAMS. TASKS stores project_id and creator_id; active assignees determine the subteam boards. One shared task keeps one ID and is counted once in combined reports.
- USERS stores role: member, officer or Chief Engineer. MEMBERSHIPS has user_id as its primary key and one required subteam_id; members/officers have exactly one membership, administrators none.
- TASK_ASSIGNMENTS retains each assignment period with its original assigner/time, paired remover/end time, and at most one active primary contact per task. Removing and reassigning creates a new period.
- TASK_STATUS_CHANGES records the creator's initial state and each later actor/status/time. History is immutable; task status and the latest row must agree.
- Reference links move into instructions. The task page route is derived from its ID. Inventory old links against the actual application origin before migrating so confirmed self-page links can be removed without discarding external references.
- Database checks reject invalid membership roles, cross-class active assignments, incomplete periods, duplicate active assignments/primary contacts, inconsistent status history and cyclic/cross-class prerequisites. A transaction advisory lock coordinates related writes.

## Story traceability

| Jira | Approved behavior | Automated evidence |
| --- | --- | --- |
| KAN-25 | Case-insensitive approved Google sign-in, role/membership mapping, denied unapproved accounts, immediate revocation on next request | `google_sign_in_spec.rb`, `access_status_delivery_spec.rb`, `administrator_handover_spec.rb`; Google is mocked locally |
| KAN-22 | Task/timeline/member/project CSV exports, matching authorized filters, one Class column, zero-hour roster rows, distinct totals and formula escaping | `csv_reports_spec.rb`, `shared_projects_and_rosters_spec.rb` |
| KAN-23 | Leader timeline with shared filters and readable dates; shared tasks appear once in a combined view | `timeline_spec.rb`, `shared_projects_and_rosters_spec.rb` |
| KAN-34 | Team-owned projects available to all same-team subteams; active assignees determine board inclusion | `organization_membership_spec.rb`, `shared_projects_and_rosters_spec.rb`, `task_spec.rb` |
| KAN-35 | Chief/all-class and officer/own-class roster management; atomic same-class transfer; zero-work members visible; account, history and hours retained | `shared_projects_and_rosters_spec.rb`, `organization_membership_spec.rb` |
| KAN-36 | Empty three-column boards; status/project prefill; multiple-project choice; filter and field retention on save/error/cancel; project-board link after unassigned saves | `board_creation_and_dependencies_spec.rb`, `member_selector_spec.rb` |
| KAN-37 | Browse/search eligible assignees; case-insensitive partial names; multiple retained selections; clear no-match feedback; bounded list with 80 members | `spec/system/member_selector_spec.rb` in real headless Chromium, desktop and mobile width |
| KAN-38 | Leader-managed same-class prerequisites; outstanding blockers with owners/status/links; self/cycle rejection; no automatic date/status changes | `board_creation_and_dependencies_spec.rb`, `database_history_integrity_spec.rb` |
| KAN-40 | Embedded protected administrator guide, hosting/backup/recovery practice and evidence template | `administrator_help_spec.rb`, `admin_guide_spec.rb`; training/delivery remain external |
| KAN-41 | Separate two-page fillable restart PDF accessible outside the app, with restart/check/troubleshooting steps | PDF rendered and visually reviewed; `administrator_help_spec.rb`; exact app/contact details and delivery remain pending |
| KAN-42 | Backup configuration and isolated-restore instructions, read-only counts/checksums/hours manifest, operational evidence record | `recovery_manifest_spec.rb`, `recovery_rake_spec.rb`; real backup/restore remains pending |

Other regression suites cover access boundaries, last-Chief protection, tasks, time entries, reports, historical contributors and archive behavior. Coverage is not a claim that customer UAT has been performed.

## Migration safeguards

`bin/rails sprint3:preflight` is read-only. It reports missing memberships/actors, inconsistent class roles, status chains, overlapping or incomplete assignment periods and incompatible active assignees before schema changes. Reconcile flagged records from reliable evidence. The migration preserves existing task/current-assignment IDs, external reference text, hours and historical attribution, and inserts the initial status exactly as Appendix B7 specifies.

`legacy_migration_spec.rb` creates the actual previous schema in an isolated schema, migrates representative records and checks retained IDs, actors, periods, statuses, hours and references. Failure cases confirm the migration stops before replacing tables. `database_history_integrity_spec.rb` and `organization_membership_spec.rb` bypass application validations to exercise database constraints. `concurrent_ownership_spec.rb` checks independent-session transfer serialization on PostgreSQL 16 in CI.

Use a backup restored to an isolated practice database for the real deployment rehearsal. The forward migration deliberately refuses a lossy automatic rollback.

## Evidence and remaining release steps

See [VERIFICATION.md](VERIFICATION.md) for measured local checks and their environment. Local PGlite executes PostgreSQL semantics but multiplexes connections; it does not establish independent-session concurrency safety. The tagged concurrency test must pass on CI's native PostgreSQL 16 service before deployment.

Complete [SPRINT3_HANDOVER.md](SPRINT3_HANDOVER.md) with actual hosting/OAuth configuration, migration rehearsal, backup/restore results, restart results, administrator training and delivery confirmation. Live Google sign-in, Heroku operations, native spreadsheet import, customer keyboard/screen-reader acceptance and customer UAT are not claimed by local tests. No production deployment or data change was performed here.

## Approved-source inconsistencies

The Notebook's Appendix B requires initial status history, while older AC-13.5 expects an empty history on an older task. This implementation follows Appendix B and shows the initial creator/status. AC-3.19 limits members to their own hours; aggregate US-23 checks must be performed as an authorized leader. These interpretations follow the user's Notebook-first priority; the approved source documents remain unchanged.
