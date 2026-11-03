# Sprint 3 operational handover record

Approved baseline: Notebook v3, Revision 6, and User Acceptance Test Form v3.
Complete this record from observed results and copy the required evidence to Notebook Section 4.2. Blank fields are **not verified**, not passing results. Preserve the approved source documents.

| Item | Confirmed value / evidence |
| --- | --- |
| Production app, URL and organization owner | Not yet supplied |
| Separate practice app and database identifier | Not yet supplied |
| Reviewed commit and deployed release | Not deployed by this implementation session |
| Hosting/database plans, recurring cost and capture date | Not verified against the account |
| Google client owner, audience and callback addresses | Not verified on Heroku |
| Approved Google sign-ins: chief, officer, member | Live verification pending |
| Unapproved account denied; revoked session blocked | Live verification pending |
| Designated website owner and support contact method | Confirm with the organization |

## KAN-42: backup and isolated recovery

| Evidence | Result |
| --- | --- |
| Backup method, frequency and schedule | Pending account review |
| Retention and storage location | Pending account review |
| Authorized responsible people | Pending confirmation |
| Backup ID, creation time, finish time and successful status | Not executed |
| Restore target proves a different database from production | Not provisioned or verified |
| Matching source and restored manifests | Not executed |
| Representative users, memberships, projects, tasks, periods, time entries, status history and prerequisites | Not executed |
| Restore date, operator, duration and outcome | Not executed |
| Remaining issues and follow-up owner | Record after exercise |

Use the administrator guide. Compare a frozen source/capture-time snapshot with the restored copy; a later live database can legitimately differ. Never overwrite production for this exercise. A code rollback does not restore records.

## KAN-40: administrator practice

| Evidence | Result |
| --- | --- |
| Guide link and session arrangements sent to JD | Not sent by this implementation session |
| Date, trainer and attendees | Pending |
| Hosting access, release identification, updates and ownership transfer | Pending observed practice |
| Backup and recovery completed by JD in the practice environment | Pending |
| Unclear steps corrected and repeated successfully | Pending |
| Follow-up actions, owners and actual completion evidence | Pending |

## KAN-41: offline restart instructions

| Evidence | Result |
| --- | --- |
| PDF location | `docs/RESTART_GUIDE.pdf`; downloadable from Help by the Chief Engineer |
| Exact app, website and support contact filled in | Pending owner details |
| Controlled restart result and approved-user sign-in | Not executed on Heroku |
| Joshua's delivery to JD | Not sent by this implementation session |
| JD confirms receipt and saves an offline copy | Pending actual confirmation |

## Acceptance-source conflicts retained for review

- Appendix B requires every task to have an initial status-history row. The older AC-13.5 empty-history case cannot apply to a valid migrated task; check the creator and initial state instead.
- Appendix B and AC-3.19 limit members to their own time entries. Aggregate checks in US-23 must be performed as an authorized leader; a member's task view does not expose other people's recorded entries.
- These interpretations follow the notebook priority already specified. The approved notebook and UAT files have not been edited.
