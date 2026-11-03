# Heroku deployment guide

Canvas requires the Sprint 1 increment in the customer's Heroku account. Deployment ownership and billing must remain with the organization.

## First deployment

1. Have the Chief Engineer or authorized organization owner create the Heroku application.
2. Add Heroku Postgres to the application.
3. Connect `https://github.com/joshEng1/AERO-502` in the Heroku app's Deploy tab.
4. Select `main` for production and enable automatic deploys only with **Wait for CI to pass before deploy** enabled. Use a separately provisioned practice app for the reviewed Sprint 3 branch; do not assume the older `test` branch contains Sprint 3.
5. Set `RAILS_MASTER_KEY` from `config/master.key` through Heroku Config Vars. Do not commit or paste it into documentation.
6. Set `DEMO_PASSWORD` to an approved practice password shared separately with testers.
7. Deploy the reviewed `main` commit. The `release` Procfile command runs `bin/rails db:migrate`.
8. On the separate practice app only, run `heroku run bin/rails db:seed -a PRACTICE_APP` for agreed practice records. Follow the Sprint 3 migration preflight in ADMIN_GUIDE.md for an existing database.
9. Open `https://APP_NAME.herokuapp.com/up`, then perform the role and task smoke tests.
10. Record the application URL, commit SHA, Heroku owner, add-ons, and current recurring price in the project notebook.

Pricing changes over time. Capture the active plan and recurring cost from the organization's Heroku dashboard at submission time; do not rely on an old price copied into this repository.

## Required environment

- Ruby 4.0.6
- PostgreSQL through `DATABASE_URL`
- `RAILS_MASTER_KEY`
- Optional `DEMO_PASSWORD`
- `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` for Google sign-in (see `ADMIN_GUIDE.md`)
- Optional `PASSWORD_SIGN_IN=off` once everyone signs in with Google

## Data decision

The seed file contains practice records only. Importing real organization records is not part of Sprint 1 unless the customer explicitly approves a separate transfer plan.
