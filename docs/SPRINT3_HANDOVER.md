# Sprint 3 operational handover record

Evidence recorded on 2026-11-03 UTC (November 2 in Texas). Sources are Sonny's supplied Heroku command output, the source/destination recovery manifests, public CI runs, public health checks, and his confirmation that Google sign-in works after correcting the callback. This is operational evidence, not customer UAT approval.

| Item | Observed result |
| --- | --- |
| Live app | `aero-task-hub`, formerly `sleepy-depths-47724` |
| Website | https://aero-task-hub-b5f4953964ed.herokuapp.com/ |
| Hosting owner | Joshua's account; transfer to JD pending |
| Release / code | `v23` / `2e4df57e136076beccb2eeb534b07183500aa280` |
| Database | `postgresql-convex-72612`, Essential-0; reported PostgreSQL 18.4 |
| Fallback | `sleepy-bayou-60650` / `postgresql-concentric-25807`; paused, not confirmed deleted |
| Live checks | `/up` and `/login` returned HTTP 200; Sonny confirmed Google sign-in works |
| Other roles / rejected accounts | Source-app denied/revoked checks were reported earlier; repeat all roles and denied/revoked checks on the final app |
| Account privileges | Source promotion of Joshua to Chief Engineer succeeded before capture; Sonny retained Chief Engineer access; manifests matched after transfer |
| OAuth / session settings | Google settings matched source; fresh session secret confirmed; destination database URL unchanged; secret values excluded from this record |

## CI evidence

- Core baseline `851d550`: [CI run 41495199847](https://github.com/joshEng1/AERO-502/actions/runs/41495199847), test/lint/Ruby scan/JS scan all successful.
- Deployed `2e4df57`: [CI run 41546389517](https://github.com/joshEng1/AERO-502/actions/runs/41546389517), all four jobs successful.
- These results belong to the named commits. Newly prepared review and promotion commits require their own green CI and Joshua's review.

## Transfer and recovery evidence (KAN-42)

The source was frozen before capture. Source backup `sleepy-bayou-60650::b003` completed at **2026-11-03 00:55:31 UTC**, started at 00:55:30, backup size 57.26 KB. The destination's fresh rollback backup was `aero-task-hub::b003`. Both were downloaded before the approved transfer replaced the destination database.

After deployment, counts and SHA-256 values matched for all ten application tables in the source and destination `recovery:manifest` outputs:

| Table | Rows |
| --- | ---: |
| teams | 6 |
| subteams | 9 |
| projects | 5 |
| users | 9 |
| memberships | 6 |
| tasks | 10 |
| task_assignments | 13 |
| time_entries | 4 |
| task_status_changes | 15 |
| task_dependencies | 0 |

Both manifests reported **8.5 actual hours**. Do not compare these manifest hashes to hashes from the separate offline pg_dump comparison; their formats differ. The data contains approved sample reconstruction, not recovered evidence of unknown historical events.

Local retained folder: `Downloads/AERO-502-final-transfer-20261103T011105839862Z/`, with `60650-sprint3-b003.dump`, `aero-task-hub-before-b003.dump` and `cutover-receipt.json`. The script receipt records a stop at configuration verification. A later read-only check confirmed the settings and release v22; manual deployment then produced v23 and the matching destination manifest. Do not present the stopped script receipt as automatic completion, and do not rerun its restore.

**Still pending:** final-app post-verification backup; schedule and retention inspection; organization-owned backup storage; permanent responsible people; a timed isolated recovery exercise with compatible code and record/relationship validation. The production transfer above is not JD's training exercise. A code rollback does not restore records; a database restore can lose changes after the backup.

## Administrator practice (KAN-40)

The guide is embedded under Help for Chief Engineers. Guide-link/session delivery, JD's hosting/release/update/backup/recovery practice, feedback corrections, trainer/date/attendees and Notebook Section 4.2 evidence remain pending.

## Offline restart instructions (KAN-41)

`docs/RESTART_GUIDE.pdf` is available through Help. Its hosting/support fields still need to be filled and verified. A controlled restart, approved-user sign-in after restart, delivery to JD and confirmation of an offline saved copy remain pending. Do not mark the story complete from document generation alone.

## Review and acceptance

Normal review flow is feature → dev → test → main. Review the new PRs in order and require green CI. Reconciliation used the deployed fixed-window timeline. KAN-23 AC 8 and the UAT form require horizontal scrolling through earlier and later dates, so the continuous-scroll timeline is restored in a follow-up PR on top of the reconciliation. Customer UAT, full role checks, accessibility acceptance, ownership transfer and handover remain outstanding.

Notebook and UAT remain the approved sources. Appendix B requires initial status history; the earlier empty-history case does not apply to migrated tasks. Members see their own hours; aggregate acceptance checks require an authorized leader. No Notebook/UAT results were edited by preparing these PRs.
