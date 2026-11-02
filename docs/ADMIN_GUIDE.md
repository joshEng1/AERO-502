# Administration, update, and recovery guide

This guide covers the existing release and the Sprint 3 sign-in, shared-project, roster, timeline and reporting changes. Steps are numbered in the order they must be done. Use a practice copy of the website for training and recovery exercises. Never copy passwords, keys or secret values into this guide, chat, screenshots or recordings.

Keep a copy of this guide in an organization-owned location (for example the SAE AERO shared Google Drive) so leaders can open it after the student developers leave. The same guide is embedded under **Help → Administrator guide** for Chief Engineers. Download the separate **restart PDF**, fill in the exact application details, and save it outside the website before handover.

## Ownership and support

Fill these in at each release and keep them up to date.

| Item | Where to find it |
| --- | --- |
| Application owner | The SAE AERO account that owns the Heroku app (Heroku dashboard → app → Access). |
| Website address | Heroku dashboard → app → Settings → Domains. |
| Hosting plan and cost | Heroku dashboard → app → Resources (dyno and Postgres plans) and Billing. Record the plan and monthly cost on the release date; prices change. |
| Support contact | The current Chief Engineer; the development team's contact until handover is complete. |
| Backup location | Heroku Postgres backups in the organization's Heroku app (`heroku pg:backups -a APP_NAME`), plus downloaded copies in the organization's shared drive. |
| Source code | `https://github.com/joshEng1/AERO-502` |

## Configuration

Set these as Heroku Config Vars (Heroku dashboard → app → Settings → Reveal Config Vars). Never write their values anywhere else.

| Name | Purpose |
| --- | --- |
| `DATABASE_URL` | Database connection; Heroku Postgres sets it automatically. |
| `RAILS_MASTER_KEY` | Unlocks the application's encrypted credentials. |
| `GOOGLE_CLIENT_ID` | Google sign-in client ID from the organization's Google Cloud project. |
| `GOOGLE_CLIENT_SECRET` | Google sign-in client secret from the same project. |
| `PASSWORD_SIGN_IN` | Set to `off` once everyone signs in with Google; leave unset to keep practice password sign-in. |
| `DEMO_PASSWORD` | Password given to practice accounts when the practice data is seeded. |
| `RAILS_LOG_LEVEL` | Optional; how much detail the logs contain (default `info`). |

## Set up Google sign-in

Do this once, signed in to the organization's Google account. Use the Google Cloud project confirmed by the organization owner and arrange continued management access for the incoming maintainers under IAM & Admin → IAM.

1. Open the Google Cloud Console and create (or choose) a project owned by the organization.
2. Under Google Auth Platform → Branding, enter the app name and support email. Configure Audience for the organization's approved TAMU accounts. An Internal audience requires a project in the appropriate Google Workspace organization; otherwise confirm the audience and test users with the account owner. The application still checks its own allowed-users list.
3. Under Google Auth Platform → Clients, create an OAuth client of type Web application.
4. Add an authorized redirect URI for each website: `https://WEBSITE_ADDRESS/auth/google_oauth2/callback` for the live and practice websites, and `http://localhost:3000/auth/google_oauth2/callback` for developers. Changes can take a few minutes to apply.
5. Copy the client ID and secret into the Heroku Config Vars `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` on each website. Google shows a new secret only once; if it is lost, open the client, select **Add secret**, and replace the Config Var.
6. If nobody can sign in as Chief Engineer yet, add the first ones: `heroku run "bin/rails users:grant_chief_engineer EMAILS=first@tamu.edu,second@tamu.edu" -a APP_NAME`. It adds each email as a Chief Engineer, or promotes an existing person after their incompatible active task assignments have been resolved. Re-running it preserves the account. Add everyone else under People.
7. Open the website and select **Sign in with Google** with an account already added under People. Choose the approved TAMU account in Google's account selector; no separate application password or password reset is needed.
8. Before turning off practice passwords, check approved Google sign-in for a Chief Engineer, an officer and a member on the deployed website. Confirm their assigned role, class (team) and subteam are unchanged. Also check an unlisted account is denied without showing project information. Automated tests mock Google; they do not prove that the deployed OAuth credentials and audience are configured correctly.

Official references: [Google Auth Platform audience](https://support.google.com/cloud/answer/15549945) and [OAuth client management and secret rotation](https://support.google.com/cloud/answer/15549257).

## People and access

Only people listed under **People** can sign in. Only the Chief Engineer can open this screen.

1. Sign in as the Chief Engineer and select **People**.
2. To approve a person, select **Add person**, enter their name and Google (TAMU) email, choose their role and Class · Subteam membership, and select **Add person** to save. They can sign in with Google immediately, without a separate password or invitation. Email matching ignores capitalization; adding `JDoe@tamu.edu` also approves `jdoe@tamu.edu`. Class is derived from the selected subteam. Members and officers require exactly one membership; Chief Engineers have none.
3. To change a person's role, team or subteam, select **Change role** next to their name, make the change and select **Save role**. It takes effect the next time they load a page.
4. To remove a person's access, select **Remove access** next to their name. They are signed out at their next page load or submitted action, including a form they opened before removal, and cannot sign in. Their saved tasks, assignments and hours are kept; do not delete their records to remove access.
5. To let them back in, select **Restore access**. They can use their approved Google account again.

Officers and members have no People navigation or access-management controls. Direct requests to People or its add, edit, remove and restore actions are denied by the server. Google supplies proof of email ownership; the application's saved role, class and subteam determine access.

If sign-in is denied, compare the selected Google email with the saved People entry and check whether it says **Access removed**. Choose the approved Google account or restore access as appropriate. A rejected or cancelled Google sign-in ends the previous application session; selecting an approved account starts a new one.

The website blocks changing the last active Chief Engineer to another role or removing their access, including direct requests. A Chief Engineer whose access has already been removed does not count as an active administrator. Add another active Chief Engineer before removing the outgoing chief's role or access.

### Semester handover

1. The outgoing Chief Engineer adds each incoming chief under People, or first resolves their active assignments and changes their role to Chief Engineer with no membership.
2. The incoming chief signs in and confirms they can open People.
3. The incoming chief removes access for, or changes the role of, outgoing leaders.

## First-time organization setup

Seeding loads **practice data only**: the three classes (Regular, Micro, Advanced), their subteams, starter projects, practice accounts and practice tasks. Use it for a practice website, not for real members.

1. Create a database backup (see below) if the database already holds records.
2. Run `heroku run bin/rails db:seed -a APP_NAME`.
3. Sign in with a practice account from `docs/TRAINING_GUIDE.md` and check that **Teams** lists the three classes with their subteams and projects.

For the live website, enter the agreed real structure through the Teams screen instead (next section). Real member records are not imported unless the customer approves a separate transfer plan.

## Managing teams, subteams and projects

Each class (team) owns projects available to all of its subteams. Active assignees determine subteam board membership; a task has no separate responsible-subteam field.

1. Select **Teams**. The Chief Engineer can select **New team**.
2. Select **Add subteam**, enter the name and save.
3. Select **Add project**, choose the parent team, enter a unique name and save. Projects need no participating-subteam selection.
4. Use **Rename** for name changes. Parent ownership stays fixed in these forms.
5. Use **Archive** to hide a group from everyday lists while preserving its work, hours and history. Use **Restore** to show it again.

Officers manage subteams and projects throughout their own class; Chief Engineers manage all classes.

## Subteam membership and reports

1. Open a subteam's **Subteam roster**. All members and officers appear, including people with no tasks or hours.
2. Use **Transfer to roster** to move an approved person from another subteam in this class, or select a destination and **Transfer membership** beside their name. The membership changes atomically; no intermediate membership removal is needed.
3. Accounts, assignment periods, task IDs, status history and hours remain. A member or officer must have exactly one membership, while an administrator has none. Resolve incompatible active assignments before a cross-class move or administrator promotion.
4. Filter by project and worked dates. A zero means no recorded hours in that scope, not that the person is available.
5. Download task, timeline, member-hour or project-hour CSVs using the same authorized filters. Class appears once. Shared task estimates and time entries are not multiplied by the number of assignees.

## Sprint 3 database update

1. Capture a backup and restore it into an isolated practice database before running the candidate release there. Keep the previous code release and the untouched backup.
2. The candidate's `bin/rails sprint3:preflight` reports missing memberships, missing historical actors, inconsistent assignment periods or status chains. Resolve these from reliable evidence. Do not invent people, timestamps or history to make the migration succeed. Inventory reference links against the actual website address; remove only confirmed links to the task's own page before migration. External reference links are preserved in instructions.
3. Run `bin/rails db:migrate` on the practice copy. The new migration follows the existing migrations and creates the approved 10-table, 16-foreign-key design: the nine baseline tables plus the approved two-column prerequisite table. It preserves task IDs and recorded hours; reconstructs assignment periods and initial/status history; and moves external reference links into instructions.
4. Verify the migrated records against the backup. Check required memberships, administrator exclusions, same-team assignees, primary contacts, retained history, references, shared boards and report totals. Deferred database triggers also enforce these relationships on direct database writes.
5. Run CI, the approved UAT and the deployed Google sign-in checks before promoting the reviewed commit. The release phase runs migrations. Never seed the live organization database with practice accounts.
6. These migrations cannot safely reverse the normalized design. A code rollback alone does not restore database records or undo schema changes. Restore the matching backup and code to a separate practice environment before planning a production recovery.

## Routine administration

1. Confirm the website's health check at `/up` returns success.
2. Review failed GitHub Actions checks before merging. Each run's test job summary shows test coverage.
3. Manage people under **People** and groups under **Teams** (see above).
4. Give the Chief Engineer role only to organization-authorized maintainers.
5. Before a release, create a database backup and record the deployed Git commit.

## Update procedure

1. Confirm tests, RuboCop and Brakeman pass on the intended release commit.
2. Create a database backup in the organization's Heroku account. This release uses team-owned projects, one membership per non-administrator, and retained assignment/status history; preserve a matching backup and code version.
3. Deploy the reviewed commit. The Procfile release phase runs database migrations.
4. Open `/up`, sign in, and check one task, one status update, the board's Hours by member section and the Teams screen.
5. Record the commit SHA, time, operator, backup identifier and result.

## Simulated failed update and rollback

1. Stop and do not run further migrations after detecting a failed release.
2. In Heroku, find the last known-good release under Activity.
3. Roll back with the Heroku dashboard or `heroku releases:rollback vNN -a APP_NAME`.
4. If the failed release changed the database, restore the pre-release backup (next section) on the practice website first, and obtain the organization owner's production recovery decision after verifying the practice result.
5. Open `/up` and repeat the update checks.
6. Record the failure, the recovery action and the outcome.

## Database backup and restore

1. Record the actual backup method, schedule, retention, storage location and responsible people in the handover record. Inspect the app's backup list and schedule with `heroku pg:backups -a PRODUCTION_APP` and `heroku pg:backups:schedules -a PRODUCTION_APP`. Confirm the plan's retention with the account owner; no schedule or retention is assumed here.
2. Capture a backup with `heroku pg:backups:capture -a PRODUCTION_APP`. Check `heroku pg:backups:info BACKUP_ID -a PRODUCTION_APP` until it reports successful completion. Record the identifier, start/finish time and storage location. Download through the owner's approved process if a separate retained copy is required.
3. Identify a separate practice app and database. Confirm its database add-on is different from production. Run `heroku pg:backups:restore PRODUCTION_APP::BACKUP_ID DATABASE_URL -a PRACTICE_APP` and confirm only the practice app. This replaces the target database; production is never the test target.
4. With the same schema/code version and a stable source snapshot, run `bin/rails recovery:manifest` on both copies. Compare per-table counts and checksums plus total hours. If production changed after capture, compare with the capture-time evidence or inspect the backup in a second isolated copy; later production changes are not restore failures.
5. Verify representative users, memberships, projects, shared tasks, assignment periods, time entries, status history and prerequisites through the restored app. Confirm the relationships, role restrictions and an approved sign-in. Save the record counts, backup identifier, test date, outcome, recovery duration and remaining issues in the embedded guide's handover record and Notebook Section 4.2.

A database restore replaces records: changes made after the backup are lost. Redeploying an earlier code release changes the application code; it does not restore deleted records. This procedure is a practice test, not authorization to replace production data.

Official command reference: [Heroku PGBackups](https://devcenter.heroku.com/articles/heroku-postgres-backups).

## Administrator training and offline instructions

1. Open **Help → Administrator guide** as Chief Engineer. Locate hosting access, updates, ownership transfer, backup and recovery steps.
2. Download **restart PDF**. Fill in the app name, website URL and designated support contact, then save a copy outside the app. The repository copy has blank application details until the owner supplies them. Rebuild a prefilled copy with `python script/build_restart_guide.py --app APP_NAME --url WEBSITE_URL --support SUPPORT_CONTACT` when those details are confirmed.
3. Arrange a short session with JD. Practice locating the app and deployed release, restarting the practice app, confirming sign-in, and recovering a backup to a separate test database. A feature walkthrough alone does not complete this hosting/recovery exercise.
4. Ask JD to follow the instructions, correct unclear steps, and repeat the affected checks. Record the trainer, date, topics, observed results, duration and follow-up actions in `docs/SPRINT3_HANDOVER.md` and Notebook Section 4.2.
5. The team emails the guide link and session arrangements; Joshua delivers the separate finalized PDF. Record JD's actual receipt and confirmation that he saved it outside the app. Do not mark delivery or training complete before those events occur.

## Handover evidence

The operational record template is `docs/SPRINT3_HANDOVER.md`. Until the owner supplies app identifiers and the exercises are performed, hosting configuration, real Google OAuth, restart, backup completion, isolated restore, training and receipt remain **not verified**. Automated application tests do not substitute for these checks.
