# AERO Task Hub

A task and work-hours tracker for the Texas A&M **SAE AERO Design** team. Leaders plan work for each class (team) and subteam, members see what is assigned to them and log the hours they spend, and the Chief Engineer gets one place to follow progress across the whole organization.

**Live website:** https://aero-task-hub-b5f4953964ed.herokuapp.com/ (sign in with your approved TAMU Google account)

## Table of Contents

- [Description](#description)
- [Who can do what](#who-can-do-what)
- [Features](#features)
- [Usage](#usage)
- [Requirements](#requirements)
  - [Internal Requirements](#internal-requirements)
  - [External Dependencies](#external-dependencies)
  - [Third-Party Libraries](#third-party-libraries)
- [Environment Variables and Required Files](#environment-variables-and-required-files)
- [Google Sign-In Setup](#google-sign-in-setup)
- [Installation and Setup](#installation-and-setup)
- [Running the Application](#running-the-application)
- [Tests](#tests)
- [Deployment](#deployment)
- [CI/CD](#cicd)
- [Hosting Cost](#hosting-cost)
- [Documentation](#documentation)
- [Support](#support)
- [Contact](#contact)
- [Credits and Acknowledgements](#credits-and-acknowledgements)

## Description

SAE AERO Design has about 75–80 members split into classes (for example Regular Class and Micro Class) and subteams (for example Aerodynamics or Structures). Before this website, work was tracked in a general project-management tool that did not match how the team is organized or record how many hours each person put in.

AERO Task Hub replaces that with a board built around the team's own structure:

- Each **task** has deliverables, work instructions, reference links, a start date, a due date, an hour estimate, a status (Backlog, In Progress or Completed) and one or more assigned members.
- Members **log the hours** they actually worked, so leaders can compare planned and actual effort per task and per person.
- Every assignment and status change is kept in the task's **history**, including who made it and when.
- Only people the Chief Engineer has approved can sign in, using their **TAMU Google account**. Password sign-in is still available until the administrator completes the Google-only transition.

## Who can do what

| Role | What they can do |
| --- | --- |
| **Chief Engineer** (administrator) | Everything: manage people and roles, classes, subteams and projects, and see and change every team's work. |
| **Officer** | Create, assign and edit tasks for their own class; see that class's board, timeline, rosters and reports. |
| **Member** | See the tasks assigned to them, update the status of those tasks, and log their own hours. |

The website checks these rules on the server as well as hiding buttons, so typing a web address directly does not get around them.

## Features

- **Google sign-in with an approved-people list.** The Chief Engineer adds each person's TAMU email and role on the **People** page. Removing someone's access keeps their past tasks and hours.
- **Task board.** Backlog, In Progress and Completed columns with counts, overdue labels, and search and filters by class, subteam, project and member.
- **Searchable Member filter.** Browse or type a partial name on the board and timeline; the selected member ID and other filters are retained.
- **Searchable assignee picker.** Type part of a name to find and assign members, even with 80+ people. Only members of the project's class are offered.
- **Hour logging and planned vs. actual.** Members record hours with the date worked (no more than 24 hours per person per day). Tasks and member summaries show estimate, actual and the difference.
- **Timeline (Gantt chart).** Every task is drawn as a bar from its start date to its due date, grouped by class and subteam. The chart scrolls sideways through the whole schedule, opens at today, and has a matching text list for accessibility. (The live site still pages through 4/6/8/12-week windows until this change is deployed.)
- **Shared projects.** A project belongs to one class and can include work from several of its subteams.
- **Subteam rosters.** Leaders see each member's assigned work, including members with no work or zero hours.
- **CSV downloads.** Filtered task, timeline, member-hour and project-hour reports for use in a spreadsheet.
- **Task history.** Who assigned, unassigned or changed the status of each task, and when.
- **Built-in help.** **Help** in the page header opens the user guide inside the website, even before signing in.
- **Administrator safeguard.** The website will not let the last active Chief Engineer be demoted or removed, so the team can't lock itself out.

> **Release evidence (2026-11-03 UTC):** `aero-task-hub` runs Sprint 3 commit `2e4df57`, release `v23`. Google sign-in was confirmed working by Sonny after the callback correction. Review and promotion into `dev`, `test` and `main` are tracked separately. See [the handover record](docs/SPRINT3_HANDOVER.md).

## Usage

1. Open the [live website](https://aero-task-hub-b5f4953964ed.herokuapp.com/) and select **Sign in with Google**. Choose your TAMU account.
   - If you see "Access not authorized", ask the Chief Engineer to add your email under **People**.
2. **Members:** select **My Tasks** to see your work. Open a task to read its instructions, change its status, or log the hours you worked.
3. **Officers and the Chief Engineer:**
   - Select **Tasks** to see the board. Use the filters, then **New Task** to create work and pick assignees.
   - Select **Timeline** to see the schedule. Scroll sideways for earlier or later dates, or select **Jump to today**.
   - Select **Teams** to manage classes, subteams, projects and subteam rosters.
   - On **Tasks**, apply filters and select **Download CSV**, **Download member hours** or **Download project hours** for a spreadsheet.
4. **Chief Engineer:** select **People** to add, change or remove people. See the [administrator guide](docs/ADMIN_GUIDE.md) for semester handover.

Full step-by-step instructions, written so they work without screenshots, are in the [user guide](docs/USER_GUIDE.md), which is also what **Help** shows inside the website.

## Requirements

### Internal Requirements

This code has been run and tested with:

| Component | Version |
| --- | --- |
| Ruby | 4.0.6 (see `.ruby-version`) |
| Rails | 8.1.4 |
| PostgreSQL | 16 in CI; the deployed Heroku database reports 18.4 |
| Bundler | 4.0.16 |
| Ruby gems | Listed in `Gemfile` and `Gemfile.lock` |

No Node.js or Yarn is needed: JavaScript is loaded with import maps.

### External Dependencies

| Dependency | Purpose | Download |
| --- | --- | --- |
| Git | Getting and updating the code | https://git-scm.com/downloads |
| Ruby 4.0.6 | Runs the application | https://www.ruby-lang.org/en/downloads/ |
| PostgreSQL | Database | https://www.postgresql.org/download/ |
| Heroku CLI | Deploying and managing the live website | https://devcenter.heroku.com/articles/heroku-cli |
| Google Cloud Console | Google sign-in credentials | https://console.cloud.google.com/auth/clients |

### Third-Party Libraries

Main libraries (full list with versions in `Gemfile.lock`):

| Library | Purpose |
| --- | --- |
| `rails` | Web application framework |
| `pg` | PostgreSQL database adapter |
| `puma` | Web server |
| `omniauth`, `omniauth-google-oauth2`, `omniauth-rails_csrf_protection` | Google sign-in |
| `bcrypt` | Password hashing for the practice accounts |
| `redcarpet` | Shows the user guide inside the website |
| `importmap-rails`, `turbo-rails`, `stimulus-rails`, `propshaft` | JavaScript and stylesheet delivery |
| `rspec-rails`, `capybara`, `selenium-webdriver`, `simplecov` | Automated tests and coverage |
| `rubocop-rails-omakase` | Code style checks |
| `brakeman` | Security scanning |

**AI libraries:** The application does not use any AI or machine-learning libraries, models or APIs.

## Environment Variables and Required Files

Set these as **Heroku Config Vars** on the live website (Heroku dashboard → app → **Settings** → **Reveal Config Vars**). For local development, export them in your terminal before starting the server.

| Variable | Required? | Description |
| --- | --- | --- |
| `DATABASE_URL` | Yes (Heroku sets it) | Database connection. Heroku Postgres fills this in automatically. |
| `SECRET_KEY_BASE` | Production | Session-signing secret; configured privately on the deployed app. |
| `RAILS_MASTER_KEY` | If encrypted credentials are used | Obtain privately from the owner. The observed deployment has no master key configured. |
| `GOOGLE_CLIENT_ID` | Yes | Google sign-in client ID. See [Google Sign-In Setup](#google-sign-in-setup). |
| `GOOGLE_CLIENT_SECRET` | Yes | Google sign-in client secret from the same Google client. |
| `PASSWORD_SIGN_IN` | Optional | Set to `off` once everyone uses Google, to turn off the practice-account password form. |
| `DEMO_PASSWORD` | Optional | Password given to practice accounts when practice data is loaded. Share it privately with testers. |
| `RAILS_LOG_LEVEL` | Optional | How much detail the logs contain (default `info`). |

**Encrypted credentials:** obtain `config/master.key` privately only when your environment uses them. Never copy production secrets into development or tests.

> **Never commit secrets.** `config/master.key` is already in `.gitignore`. Don't put real values for any of the variables above in this README, the repository, chat, screenshots or the project notebook.

## Google Sign-In Setup

Google sign-in is set up for the live website. These steps are for a new website or if the credentials ever need to be replaced. Do them signed in to an account the organization controls (Google Cloud project `aero-502`).

1. In the [Google Cloud Console](https://console.cloud.google.com/auth/clients), open **Google Auth Platform**.
2. **Branding:** set the app name to `AERO Task Hub` and use an organization email as the support email.
3. **Audience:** use the existing owner's approved configuration. Internal requires the appropriate Google Workspace organization. Google account eligibility and the application's People approval are separate checks; verify both before changing audience or publishing settings.
4. **Clients:** create (or open) a client of type **Web application** and add these **Authorized redirect URIs**:
   - `https://aero-task-hub-b5f4953964ed.herokuapp.com/auth/google_oauth2/callback` (live website)
   - `http://localhost:3000/auth/google_oauth2/callback` (developers)
5. Copy the client ID and secret into the Heroku Config Vars `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`. Google shows a secret only once; if it is lost, select **Add secret** and replace the Config Var.
6. Add the first Chief Engineer once from a terminal:

   ```bash
   heroku run "bin/rails users:grant_chief_engineer EMAILS=name@tamu.edu" -a aero-task-hub
   ```

   After that, nobody needs the terminal to manage people: the Chief Engineer adds everyone else, and sets their role, class and subteam, on the **People** page in the website.

If the website address ever changes (for example a new Heroku app name or a custom domain), add the new `/auth/google_oauth2/callback` address in step 4. Otherwise Google shows `redirect_uri_mismatch`.

## Installation and Setup

1. Install Git, Ruby 4.0.6 and PostgreSQL (see [External Dependencies](#external-dependencies)), and make sure PostgreSQL is running.
2. Get the code:

   ```bash
   git clone https://github.com/joshEng1/AERO-502.git
   cd AERO-502
   ```

3. Configure a separate local database. Obtain the credentials key privately only if using encrypted credentials.
4. Install the gems and create the database with practice data:

   ```bash
   bundle install
   bin/rails db:prepare
   bin/rails db:seed
   ```

   The seed creates practice classes, subteams, projects and accounts (`chief@example.test`, `officer.a@example.test`, `member.a@example.test` and others listed in [docs/TRAINING_GUIDE.md](docs/TRAINING_GUIDE.md)). Their password comes from `DEMO_PASSWORD`; ask the team for it.

## Running the Application

```bash
bin/rails server
```

Then open http://localhost:3000/ in a browser. To try Google sign-in locally, export `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` first; otherwise sign in with a practice account.

## Tests

```bash
bundle exec rspec          # automated tests
bin/rubocop                # code style
bin/brakeman --no-pager    # security scan
bin/importmap audit        # JavaScript dependency audit
```

SimpleCov writes a coverage report to `coverage/index.html`. The automated tests simulate Google, so after any change to sign-in settings, also sign in on the live website with an approved account and check that an unapproved account is refused.

## Deployment

The live app is **`aero-task-hub`** at https://aero-task-hub-b5f4953964ed.herokuapp.com/. Its verified deployment is commit `2e4df57` from `test`, Heroku release `v23`. The branch reconciliation PRs do not deploy anything.

Before any future deployment, finish Joshua's review, pass CI on the resulting release commit, capture a database backup, and verify the deployment source. Until `main` contains the approved Sprint 3 changes, keep automatic deployment from the older `main` disabled. Follow [the deployment guide](docs/DEPLOYMENT.md).

## CI/CD

- **Review flow:** feature branches → `dev` → `test` → `main`, with review and passing CI at each promotion. The November 3 deployment from `test` is an explicitly recorded exception being reconciled through PRs.
- **CI:** every pull request and pushes to `dev`, `test` and `main` run RSpec against PostgreSQL 16, RuboCop, Brakeman and the import-map audit.
- **Deployment:** verify the actual Heroku Deploy configuration. Creating or merging a review branch is not authorization to deploy an unverified commit.

## Hosting Cost

The observed plans are Heroku Eco and Postgres Essential-0. Record current charges from the owner's Resources and Billing screens at handover; the final account's invoice has not been reviewed. A stopped web process does not remove its database add-on or establish that all charges have ended.

## Documentation

- [User guide](docs/USER_GUIDE.md): how to use the website, by role
- [Administrator guide](docs/ADMIN_GUIDE.md): people and access, Google sign-in, updates, backups and recovery
- [Deployment guide](docs/DEPLOYMENT.md)
- [Training checklist](docs/TRAINING_GUIDE.md)
- [Quality strategy](docs/QUALITY_STRATEGY.md) and [verification results](docs/VERIFICATION.md)
- [Google sign-in verification](docs/KAN25_VERIFICATION.md)
- [Sprint 3 stories and migration verification](docs/SPRINT3_STORIES_VERIFICATION.md)
- External: [Rails Guides](https://guides.rubyonrails.org/), [RSpec Rails](https://rspec.info/), [OmniAuth Google OAuth2](https://github.com/zquestz/omniauth-google-oauth2), [Heroku Config Vars](https://devcenter.heroku.com/articles/config-vars), [Heroku Postgres backups](https://devcenter.heroku.com/articles/heroku-postgres-backups)

## Support

- **Members and officers:** start with **Help** in the website. For access problems ("Access not authorized"), contact the Chief Engineer, who can add or restore you under **People**.
- **Chief Engineer:** see the [administrator guide](docs/ADMIN_GUIDE.md). Until handover is complete, the development team below can help.
- **Bugs and requests:** open an issue at https://github.com/joshEng1/AERO-502/issues.

## Contact

| Name | Role | GitHub |
| --- | --- | --- |
| Joshua Eng | Developer | [@joshEng1](https://github.com/joshEng1) |
| Rahul Saravanakumar | Developer | [@rahulsaravanakumar](https://github.com/rahulsaravanakumar) |
| Sonny Hernandez | Developer | [@SonnyHernandez90](https://github.com/SonnyHernandez90) |

**Customer:** JD Kollar, SAE AERO Design (Texas A&M).

## Credits and Acknowledgements

- **Development team:** Joshua Eng, Rahul Saravanakumar, Sonny Hernandez, and Rohak (through Sprint 3).
- **Customer:** JD Kollar and the Texas A&M SAE AERO Design team, for requirements and feedback.
- **Course:** CSCE 431 Software Engineering, Texas A&M University, Fall 2026.

### AI Use

- Claude (Anthropic) assisted with parts of the Sprint 3 code (the scrolling timeline), with code review, and with writing this README. The team reviewed all of it, and the automated tests and CI checks were run on the results.
- OpenAI Codex assisted with the approved Sprint 3 implementation, regression fixes, deployment diagnostics and review preparation. CI results and live observations are recorded separately from customer acceptance.
