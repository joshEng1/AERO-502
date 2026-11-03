# Sprint 3 shared projects rosters timeline and CSV reports

Historical record, preserved from the October 23 `dev` baseline. Its provisional data model and Jira mapping are superseded by [the approved Sprint 3 implementation](../SPRINT3_STORIES_VERIFICATION.md).

Implemented on `dev` for KAN-22, KAN-23, KAN-34 and KAN-35. This record describes implementation and local verification on October 23, 2026; it does not assert deployed customer acceptance.

## Story mapping and design

The supplied KAN-22 and KAN-23 titles and acceptance criteria are crossed: KAN-22's criteria describe the timeline, while KAN-23's describe CSV exports. Both sets are implemented. The supplied Sprint 3 UAT calls roster management US-16 and CSV reports US-17; Jira identifiers are retained here to avoid confusing those independent numbering systems.

Projects belong to a parent team and use `project_subteams` to name participating subteams. Tasks store only `project_subteam_id`; team, project and responsible subteam are derived, rather than copied into competing task columns. The association's parents and a project's parent team are immutable. Existing task IDs, dates, estimates, assignments, links, hours and history remain intact.

Class membership and its member/officer role are stored in `team_memberships`; subteam membership is stored in `subteam_memberships`. Users keep only their global Chief Engineer/participant role. The existing People and KAN-9 interfaces derive their primary role/class/subteam from those records, so Google sign-in and authorization retain their behavior. Ending a class membership ends its subteam memberships in the same transaction.

The provisional policy is one active class and one active subteam per person, with Chief Engineers managing all rosters and officers managing their own class. This follows the existing access rules and the implementation choice discussed with the repository owner; customer confirmation of multiple memberships is still pending. The association tables retain membership dates and permit a later policy change without rewriting task assignments or hours. There is no separate sprint entity; roster work is identified by project, responsible subteam and status.

## Acceptance traceability

| Story and criteria | Implementation and evidence |
| --- | --- |
| KAN-22 AC1–AC4 | Timeline groups task bars by team/subteam, marks unfinished overdue tasks in text and styling, shares filters and displays saved date changes. `spec/requests/timeline_spec.rb` and `shared_projects_and_rosters_spec.rb`. |
| KAN-22 AC5 | Member navigation hides Timeline; direct HTML and CSV requests are denied with an Access denied message. Timeline and CSV request specs. |
| KAN-23 AC1–AC4 | Task and timeline CSV downloads use the same permitted task scopes and filters as their views, with all ten required task columns. Member, project, team(s), subteam, search and task-overlap dates apply. `csv_reports_spec.rb`. |
| KAN-23 AC5–AC7 | Member and project hour reports share the on-screen summary calculation. Worked-date endpoints are inclusive, task estimates count once and time entries count once. Relevant zero-work members remain visible with 0 actual hours, including empty project/date scopes. CSV report specs. |
| KAN-23 AC8 | Members have no export controls; all direct export endpoints enforce leader access. Officers cannot obtain another class's records even through forged filters. CSV report specs. |
| KAN-34 AC1–AC2 | Project forms select a parent team and participating subteams from that team. Task forms select the project and responsible participating subteam. Invalid and foreign combinations are rejected. Shared-project request specs and organization membership model specs. |
| KAN-34 AC3–AC5 | Project filters include work across participating subteams; an additional subteam filter narrows it. Project pages, boards, reports and timeline derive the same saved ownership and preserve task fields and hours. Shared-project and CSV specs. |
| KAN-34 AC6 | Existing officer/team and member/assignment restrictions remain, including direct writes and foreign project attempts. Existing role, task and Google sign-in suites also pass. |
| KAN-35 AC1–AC2 | Authorized leaders add existing approved class members to rosters and remove membership independently of task assignments. All roster members are listed, including those with no work. Shared-project/roster specs. |
| KAN-35 AC3–AC4 | Roster rows show each member's permitted assigned work across their class, with project, responsible subteam and status. Project and worked-date controls narrow the scope. No assigned work and zero actual hours are explicit; zero hours is not labeled as availability. Roster request specs, including a cross-subteam assignment regression. |
| KAN-35 AC5–AC6 | Removal preserves accounts, assignments, task history and hours. Member and foreign-officer direct requests are denied; unknown and revoked candidates cannot be added. Roster specs and membership lifecycle model specs. |

## Report behavior

Task dates from/to select tasks whose saved schedule overlaps the requested dates. Hours from/to select time entries by `worked_on`; these filters also control task-card actuals and report totals. Clearing task filters restores the permitted task scope. Timeline downloads include every filtered task row represented by the chart or readable date list, including Earlier/Later markers outside the current scroll window.

Class and Team both name the parent class in member/project files. Historical contributors remain included even after assignment or membership changes, so recorded hours do not disappear. Reports derive their group labels from the reported work; zero-work rows use current membership. CSV files use UTF-8 with a BOM, quoted fields and CRLF records. Formula-looking user text is prefixed with an apostrophe to prevent spreadsheet execution. Tests cover commas, quotes, newlines, accented text and formula prefixes.

## Local verification

Environment: Ubuntu 22.04 under WSL, Ruby 4.0.6, Bundler 4.0.16, PostgreSQL 14.24, and locked application dependencies. Test, migration-check and browser-preview databases were separate from existing application databases.

| Check | Result |
| --- | --- |
| Full RSpec suite | 213 examples, 0 failures; random seed 52995 |
| SimpleCov line coverage | 100% (891/891) |
| SimpleCov branch coverage | 100% (275/275) |
| RuboCop | 111 files inspected, no offenses |
| Brakeman | 0 errors, 0 security warnings |
| Import-map audit | No vulnerable packages found |
| Migration retention | Restored the old schema/data and applied both migrations. Before/after canonical record digests matched for users, tasks, projects, assignments, time entries, history, links, teams and subteams. |
| Migration preflight | Duplicate project names within a team and inconsistent legacy task ownership each prevented migration before any new tables were created. |
| Browser smoke test | Signed in, shared a project across Aerodynamics and Structures, created a Structures task, removed/restored a roster membership, and confirmed its assignment and 3 recorded hours remained. Downloaded a filtered CSV containing 3 tasks across both subteams; its 18 estimated and 7 actual hours matched the board. |

Commands: `bundle exec rspec`, `bundle exec rubocop`, `bundle exec brakeman --no-pager`, and `bundle exec ruby bin/importmap audit`. Coverage HTML and JSON are generated under `coverage/`.

## Deployment and customer validation

Follow the Sprint 3 database-update section in `ADMIN_GUIDE.md`: back up first, migrate a restored staging copy, compare records and permissions, then deploy the matching code/schema. Resolve any flagged legacy name/ownership conflicts explicitly. Rollback requires the pre-update backup and matching previous code, because shared projects cannot safely collapse into the old model automatically.

Customer membership-policy confirmation, customer UAT, production OAuth credentials and authenticated deployed validation remain external release steps. The browser download was parsed and compared locally; native Excel/Google Sheets import and keyboard/screen-reader acceptance should be recorded with the customer's UAT rather than claimed from automated tests.
