# Heroku deployment guide

## Current deployment

- App: `aero-task-hub` (formerly `sleepy-depths-47724`).
- Website: https://aero-task-hub-b5f4953964ed.herokuapp.com/
- Repository: https://github.com/joshEng1/AERO-502
- Recorded release: `v23`, commit `2e4df57e136076beccb2eeb534b07183500aa280`.
- Heroku owner observed: Joshua's account. JD's ownership transfer remains pending.
- Database: `postgresql-convex-72612`; Postgres Essential-0, version reported as 18.4.
- `sleepy-bayou-60650` was paused as a fallback. Its deletion has not been confirmed.

The recorded release came from `test`. Reconcile it through reviewed PRs and restore the normal feature → dev → test → main flow. Keep automatic deployments from older `main` disabled until it contains the approved release. Verify the actual Heroku Deploy settings; this guide does not claim that they were changed.

## Configuration

The app uses `DATABASE_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and a private `SECRET_KEY_BASE`. `RAILS_MASTER_KEY` is needed if encrypted credentials are used; it was absent in the successful deployment. Heroku supplies the database URL. Do not copy a database URL between apps. `PASSWORD_SIGN_IN` remains enabled until the organization approves Google-only operation after testing all roles.

The exact Google authorized redirect URI for this app is:

```text
https://aero-task-hub-b5f4953964ed.herokuapp.com/auth/google_oauth2/callback
```

Edit the same OAuth client whose ID is configured on this app. After saving, start a new sign-in from the website. OAuth success still requires an approved, non-revoked People record. Do not commit credentials or paste their values into an issue, guide or screenshot.

## Future release procedure

1. Complete code review and CI on the exact intended release commit. Confirm the repository and Heroku app before pushing.
2. Record the currently deployed release and capture and download a database backup. Verify successful backup completion.
3. For schema changes, rehearse against a distinct restored test database and follow `ADMIN_GUIDE.md`. The approved migration stops when real history or memberships need reconciliation; do not fabricate attribution.
4. Deploy only that reviewed commit to `https://git.heroku.com/aero-task-hub.git`. The Procfile release phase runs `bin/rails db:migrate`; confirm that the release succeeded before serving traffic.
5. Check `/up`, Google sign-in with approved roles, denied/revoked access, the task board, the searchable Member filter, a task and its history, and the recorded hour totals.
6. Record release, commit, operator, backup and observed results in the handover record.

Do not rerun the completed database transfer during ordinary code review or deployment. Do not seed the live database. A code rollback does not restore database records or reverse this migration; recovery needs compatible code and a separately verified backup.

## Remaining operational work

Verify backup frequency, retention, storage and responsible people; complete the controlled restart and isolated recovery exercise; deliver the filled offline PDF; train JD and record feedback; finish customer UAT and ownership transfer. Retire the paused fallback only after final-app checks and retained backups are confirmed.

References: [Heroku release phase](https://devcenter.heroku.com/articles/release-phase), [PGBackups](https://devcenter.heroku.com/articles/heroku-postgres-backups), [Google redirect URI matching](https://developers.google.com/identity/protocols/oauth2/web-server).
