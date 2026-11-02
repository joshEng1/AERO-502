# Verification record

## Sprint 3 approved design (November 2, 2026)

Local implementation on `codex/sprint-3-approved-design`, based on `origin/dev` at `4b07387`. The approved Notebook v3 / Revision 6 and UAT v3 control this revision. See [story traceability and migration design](SPRINT3_STORIES_VERIFICATION.md). The Sprint 1/2 evidence below is preserved from `origin/main`; those historical results describe their stated commits.

| Check | Observed result |
| --- | --- |
| Baseline before changes | Unchanged `dev`: 213 examples, 0 failures; 100% line and branch coverage |
| Final selected RSpec suite | **249 examples, 0 failures**, seed 51635, 70.75 seconds |
| SimpleCov | **100% lines (1083/1083)** and **100% branches (394/394)**; existing gates unchanged |
| Browser regression | Real headless Chromium 151; 80 added test members; keyboard search/selection, retained chips, primary contact, validation recovery, completed-column save and 390-pixel mobile layout passed |
| Style | RuboCop: 124 files, no offenses |
| Security | Brakeman 8.1.0: 0 errors and 0 security warnings |
| JavaScript dependency audit | `bin/importmap audit`: no vulnerable packages found |
| Migration | Previous schema/data migration and reconciliation failures tested; retained task/current-assignment IDs, actors, initial/status history, assignment periods, references and hours verified |
| Direct database writes | Membership/ownership, active and primary uniqueness, paired ending times, immutable history, status attribution/order, cross-team and circular prerequisite rejection passed |
| SQL schema load | `db/structure.sql` loaded successfully using psql 16.15 into a new PGlite database; after reconnecting, practice seeds and the recovery manifest succeeded (3 tasks, 4 assignment periods, 3 initial status rows, 7 actual hours) |
| Restart PDF | Two-page fillable PDF rendered and visually checked; exact hosting/support fields remain blank pending confirmed values |

Environment: Ubuntu 24.04 workspace, Ruby 4.0.6, Bundler 4.0.16, locked dependencies, and **PGlite / PostgreSQL 18.6 semantics** through its PostgreSQL socket adapter. This environment cannot run a normal PostgreSQL server as a non-root account. Its single-session connection multiplexing requires prepared statements disabled and a fresh connection after psql's schema-load session. These are local harness accommodations; the application and CI retain normal PostgreSQL configuration.

The local suite used `bundle exec rspec --tag ~postgres_concurrency`. Exactly one additional independent-session concurrency test is excluded locally: PGlite cannot establish that property. CI runs plain `bundle exec rspec` against native **PostgreSQL 16**, including that test. The initial local run did not verify native PostgreSQL concurrency or release deployment; the later native CI result is recorded below. A local 100% coverage result does not imply that excluded test or customer UAT has passed.

The final style/security commands were `bundle exec rubocop`, `bundle exec brakeman --no-pager` and `bundle exec ruby bin/importmap audit`. No production database was connected, migrated or restored. Google tests use OmniAuth test mode; real OAuth configuration, staging migration against the real backup, Heroku restart/recovery, training, offline-PDF delivery and customer acceptance must be recorded in [SPRINT3_HANDOVER.md](SPRINT3_HANDOVER.md).

### CI follow-up after the `test` upload

[CI run 41403959885](https://github.com/joshEng1/AERO-502/actions/runs/41403959885) tested uploaded commit `1a08530`. Lint and both security scans passed. RSpec ran 250 examples with two failures, while retaining 100% line and branch coverage. The uploaded workflow used an unpinned PostgreSQL image; the configuration correction restores PostgreSQL 16.

- The concurrency test failed before opening its extra sessions because unfiltered `conninfo_hash` passed an empty service setting to libpq. Removing blank settings reproduced-and-resolved this connection error locally; both connection/query checks succeeded. Opened connections are also retained for cleanup if a later connection attempt fails. The actual independent-session race still requires the next native PostgreSQL CI run.
- The browser check found the selector options in the DOM but reported them as hidden. A new regression reproduced the dropdown opening below the viewport when the search field sits at its bottom edge. Opening now scrolls the bounded dropdown into view. The test checks the open state, visible dropdown and first choice, and counts all 82 available choices including scrolled-out rows; keyboard selection, retained choices, primary contact, error recovery and mobile checks remain enforced. CI also retains browser screenshots for diagnosis.
- After the fixes, the local suite with the original CI seed (`60876`) passed **249 examples, 0 failures**, with **1083/1083 lines and 394/394 branches covered**. This used PGlite and headless Chrome **156.0.8078.80**; only the native concurrency test was excluded. RuboCop inspected 124 files with no offenses. These results do not claim that the next CI run has passed.

### Remaining browser failure and pointer focus correction

[CI run 41406456761](https://github.com/joshEng1/AERO-502/actions/runs/41406456761), commit `b207ff2`, ran **250 examples with one failure**, seed `46194`. The supplied output confirms that the independent-session ownership concurrency test now passes against PostgreSQL 16. The remaining failure is the member selector's closed `aria-expanded` state after a click. Ruby coverage remained **1083/1083 lines and 394/394 branches**.

Local event tracing found that the focus handler scrolled the list into view while the mouse button was still down: the search field moved **230 pixels**, so pointer release landed elsewhere. A regression that holds the mouse button and checks the field's position failed before the correction. Pointer interactions now open and scroll the list on the completed click; keyboard focus still opens it immediately. The regression passes after this change, along with ordinary clicking, closing on focus leaving the selector, Tab/Shift+Tab reopening, keyboard search and multiple selection, error recovery, task saving and mobile opening. No visibility assertion or coverage gate was removed.

The corrected local suite passed **249 examples, 0 failures**, seed `46194`, in **70.49 seconds**, with **100% line and branch coverage**. This run used `CI=true`, PGlite and Chrome Headless Shell **156.0.8078.80**; only the native concurrency test was excluded. RuboCop inspected **124 files with no offenses**. The exact closed-state failure has not been reproduced under Headless Shell, so a fresh full Chrome/PostgreSQL 16 CI run is still required to confirm the remaining CI failure is resolved. Deployment and customer UAT remain pending.

## Sprint 2 (October 15, 2026)

All checks were run on `main` at `1f7fa94` (PR #25, the latest `main` as of this record). They ran in a clean clone, using the same commands as [CI](../.github/workflows/ci.yml).

| Item | Value |
| --- | --- |
| Environment | Ubuntu 24.04 (WSL2), Ruby 4.0.6, Bundler 4.0.16, PostgreSQL 16.15 |
| Run at | 2026-10-15 13:28 CDT |
| CI run for the same commit | [Actions run 38345995965](https://github.com/rahulsaravanakumar/AERO-502/actions/runs/38345995965): success, October 13, 2026 |

| Check | Command | Result |
| --- | --- | --- |
| Tests | `RAILS_ENV=test bin/rails db:test:prepare && bundle exec rspec` | **169 examples, 0 failures** (35.9 s) |
| Line coverage | SimpleCov (`script/coverage_summary.rb`) | **100% (630/630)** |
| Branch coverage | SimpleCov | **100% (159/159)** |
| Style | `bin/rubocop` | 96 files inspected, no offenses |
| Security scan | `bin/brakeman --no-pager` | Brakeman 8.1.0: 0 errors, 0 security warnings |
| JavaScript dependencies | `bin/importmap audit` | No vulnerable packages found |

Since Sprint 1: 45 → 169 examples, line coverage 216 → 630 lines (still 100%), branch coverage 96.15% → 100%.

### Results by story

☀ = normal use. ☂ = error, boundary, or unauthorized use. Every listed example passed in this run.

| Jira | Behavior checked | Expected result | Test | Actual |
| --- | --- | --- | --- | --- |
| KAN-19 | Leader builds Team › Subteam › Project | Records are saved and the parents are shown when reopened | ☀ [organization_management_spec.rb:21](../spec/requests/organization_management_spec.rb#L21) | Pass |
| KAN-19 | Missing name or parent | Refused, the field is identified, nothing is created | ☂ [organization_management_spec.rb:47](../spec/requests/organization_management_spec.rb#L47) | Pass |
| KAN-19 | Team A officer sends direct requests for Team B | Refused | ☂ [organization_management_spec.rb:106](../spec/requests/organization_management_spec.rb#L106) | Pass |
| KAN-19 | Archive a record | It leaves everyday lists; its tasks and hours stay viewable | ☀ [organization_management_spec.rb:75](../spec/requests/organization_management_spec.rb#L75) | Pass |
| KAN-20 | Assign/remove members, change status | Each change is recorded with who did it, newest first | ☀ [task_history_spec.rb:15](../spec/requests/task_history_spec.rb#L15), [:47](../spec/requests/task_history_spec.rb#L47) | Pass |
| KAN-20 | Member opens the history; anyone edits or deletes an event | Member does not see it; events cannot be changed | ☂ [task_history_spec.rb:71](../spec/requests/task_history_spec.rb#L71), [:84](../spec/requests/task_history_spec.rb#L84) | Pass |
| KAN-20 | Delete a task that has history or hours | Refused; history and hours are kept | ☂ [task_history_spec.rb:93](../spec/requests/task_history_spec.rb#L93) | Pass |
| KAN-21 | Search plus team and subteam filters | Only matching permitted tasks are shown | ☀ [task_search_filter_spec.rb:13](../spec/requests/task_search_filter_spec.rb#L13), [:25](../spec/requests/task_search_filter_spec.rb#L25) | Pass |
| KAN-21 | Search for another team's restricted task | Never shown | ☂ [task_search_filter_spec.rb:44](../spec/requests/task_search_filter_spec.rb#L44) | Pass |
| KAN-23 | Timeline bars | Each task's bar runs from start to due date, grouped by team and subteam | ☀ [timeline_spec.rb:11](../spec/requests/timeline_spec.rb#L11) | Pass |
| KAN-23 | Unreadable dates or window size | Falls back to the default 6-week window | ☂ [timeline_spec.rb:95](../spec/requests/timeline_spec.rb#L95) | Pass |
| KAN-23 | Member opens `/timeline` | Redirected; an officer sees only their own team | ☂ [timeline_spec.rb:110](../spec/requests/timeline_spec.rb#L110) | Pass |
| KAN-24 | Task estimate vs. actual hours | Task states the difference ("over/under estimate") | ☀ [planned_vs_actual_spec.rb:16](../spec/requests/planned_vs_actual_spec.rb#L16) | Pass |
| KAN-24 | Negative estimate | Rejected; zero is accepted | ☂ [planned_vs_actual_spec.rb:5](../spec/requests/planned_vs_actual_spec.rb#L5) | Pass |
| KAN-25 | Allowed email signs in with Google | Signed in with the assigned role and team, ignoring letter case | ☀ [google_sign_in_spec.rb:24](../spec/requests/google_sign_in_spec.rb#L24) | Pass |
| KAN-25 | Email not on the list, or not verified by Google | Refused with "Access not authorized" | ☂ [google_sign_in_spec.rb:32](../spec/requests/google_sign_in_spec.rb#L32) | Pass |
| KAN-25 | Person's access is removed | Signed out at their next page load; their tasks and hours are kept | ☂ [google_sign_in_spec.rb:80](../spec/requests/google_sign_in_spec.rb#L80) | Pass |
| KAN-29 | Board summary | Column counts, Overdue labels, leader hours table and chart | ☀ [board_summary_spec.rb:32](../spec/requests/board_summary_spec.rb#L32)–[:79](../spec/requests/board_summary_spec.rb#L79) (AC1–AC5) | Pass |
| KAN-29 | Reversed or unreadable hours date range | Error is shown; hours for all dates are displayed | ☂ [board_summary_spec.rb:94](../spec/requests/board_summary_spec.rb#L94) | Pass |
| KAN-17 | User guide | Linked from the header and sign-in page; opens without signing in | ☀ [user_guide_spec.rb:5](../spec/requests/user_guide_spec.rb#L5), [:14](../spec/requests/user_guide_spec.rb#L14) | Pass |
| KAN-17 | Every message the website shows | Explained in the guide with a next step | ☂ [user_guide_spec.rb:22](../spec/requests/user_guide_spec.rb#L22) | Pass |
| KAN-15 | Admin guide | Update, rollback, backup, and restore are numbered steps; no secret values | ☀ [admin_guide_spec.rb:35](../spec/docs/admin_guide_spec.rb#L35), ☂ [:24](../spec/docs/admin_guide_spec.rb#L24) | Pass |

Run one example with `bundle exec rspec <file>:<line>`. Run the whole suite with `bundle exec rspec --format documentation` to get a named result for every example.

### Known limitations and pending validation

- **KAN-26 (last Chief Engineer guard) is not on `main`.** PR #24 was merged into `dev` only, so it is not covered by this run or this deployment.
- **Google sign-in is tested with OmniAuth's test mode.** Real Google sign-in on Heroku depends on `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` and must be checked in the deployed app.
- **These are automated and local results, not customer acceptance.** Customer UAT for Sprint 2 is not yet recorded. KAN-16 and KAN-18 (training) have no recorded session.
- **Not implemented in Sprint 2:** KAN-22, 27, 28, 30, 31, 32, and 33.
- **Open Dependabot PRs** (pg, selenium-webdriver, simplecov, thruster, upload-artifact) are not merged. This run used the versions in `Gemfile.lock`.

## Sprint 1 (October 1, 2026)

Sprint 1 delivery checks verified locally on October 1, 2026 against PostgreSQL.

| Check | Result |
| --- | --- |
| `bundle exec rspec` | 45 examples, 0 failures |
| SimpleCov line coverage | 100% (216/216), enforced by the test suite |
| SimpleCov branch coverage | 96.15% (50/52) |
| `bin/rubocop` | 55 files inspected, no offenses |
| `bin/brakeman --no-pager` | Brakeman 8.1.0: 0 errors, 0 security warnings |

Model specs: [Task](../spec/models/task_spec.rb), [User](../spec/models/user_spec.rb), [TimeEntry](../spec/models/time_entry_spec.rb).
Request specs: [Sprint 1 workflow](../spec/requests/sprint_one_workflow_spec.rb), [Task management](../spec/requests/task_management_spec.rb).
Delivery regressions: [Task cards](../spec/requests/task_card_delivery_spec.rb), [Access and status](../spec/requests/access_status_delivery_spec.rb), [Hours and totals](../spec/requests/effort_delivery_spec.rb), [Health](../spec/requests/health_delivery_spec.rb).

Browser verification found that the hours input's `min="0.01"` and `step="0.25"` rejected ordinary entries such as 1.5 hours. Changed the step to 0.01 and added a regression for the rendered input. Retested locally: submitting 1.5 hours succeeded and changed the task's actual total from 2.5 to 4 hours.
Run `bundle exec rspec` for named results and `coverage/index.html`. CI publishes the report as the `rspec-coverage` artifact. Each run measures RSpec alone; previous Minitest results are not merged.

The notebook PDF's older test screenshots predate this migration. Use this record and the new CI evidence for the corrected test setup.

Earlier checks from September 27, 2026 (not rerun as part of the test-framework migration):

| Check | Result |
| --- | --- |
| `bin/importmap audit` | No vulnerable packages found |
| Browser smoke test | Member sign-in, scoped dashboard, task details, status form, hour form, planned/actual totals rendered successfully |

These are local verification results, not deployed UAT acceptance. Repeat the commands on the exact commit deployed to Heroku and attach the CI run plus deployed browser/UAT evidence to the notebook.
