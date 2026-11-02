# KAN-25 Google sign-in and approved access

Sprint 3 implementation builds on the Google sign-in and People management already present on `dev` at `5c4e160`. Google proves email ownership; saved application roles and team/subteam membership continue to control authorization under KAN-9. No database migration is required.

## Acceptance coverage

The supplied Sprint 3 UAT form v2 identifies this story as **US-2**, not US-25. Its US-25 describes a separate proposed comments feature. The applicable scope is S02; proposed membership and project schema revisions in the partial notebook are separate work.

| KAN-25 criterion | Automated evidence in `spec/requests/google_sign_in_spec.rb` | Sprint 3 UAT |
| --- | --- | --- |
| Approved Google account retains its role, class and subteam | All three roles sign in through the OAuth flow in independent sessions; saved attributes remain unchanged even when the Google profile supplies a different role. | AC-2.1, AC-2.10 |
| Unapproved account is denied without project information | Unlisted and unverified emails are refused with a text alert. Rejection clears any previous session; an approved account can then be selected. Only a boolean `true` verification result is accepted. | AC-2.4, AC-2.12, AC-2.14 |
| Newly approved person signs in immediately | The Chief Engineer adds a Google-only person with role, team and subteam; mixed-case email signs in without a password. | AC-2.2, AC-2.3 |
| Revocation applies at the next page or action and preserves work | A separate Chief Engineer session revokes access while a member has a task open. Submission is denied, status is unchanged, and assignments and hours remain. A revoked session is also ended on the public Help page. | AC-2.5, AC-2.6, AC-2.13 |
| Officers and members cannot manage access | People navigation is absent; direct list/add/remove/restore requests cannot grant or change access. Direct People access explains "Access denied." | AC-2.7–AC-2.9 |

The administrator and user guides describe account selection, case-insensitive email matching, immediate Google-only access, and revocation of already-open actions.

## Local verification on October 21, 2026

Checks ran on the updated `dev` working tree in Ubuntu 22.04 under WSL, with Ruby 4.0.6, Bundler 4.0.16, the locked dependencies and an isolated PostgreSQL 14.24 test database. No existing development or production database was used.

| Check | Result |
| --- | --- |
| `bundle exec rails db:test:prepare` | Test database prepared successfully |
| `bundle exec rspec` | 187 examples, 0 failures; random seed 18027 |
| SimpleCov line coverage | 100% (661/661) |
| SimpleCov branch coverage | 100% (181/181) |
| `bundle exec rubocop` | 99 files inspected, no offenses |
| `bundle exec brakeman --no-pager` | 0 errors, 0 security warnings |
| `bundle exec ruby bin/importmap audit` | No vulnerable packages found |

Five existing request-spec files required explicit start dates for scenarios with an October 20 due date. Without those dates, the default start date became later than the due date on October 21, causing seven unrelated failures. These test-data repairs preserve the original scenarios and application validation rules.

## Deployment validation still required

Automated OAuth tests use OmniAuth test mode. They do not establish that live Google credentials, redirect URIs or the organization's Internal audience are configured correctly. Follow `docs/ADMIN_GUIDE.md` to configure and check the deployed release.

Run the supplied US-2 UAT on the deployed commit, including real TAMU accounts, laptop and phone checks (AC-2.10), keyboard-only Google sign-in (AC-2.11), and account selection after an unapproved attempt (AC-2.14). Record the deployed commit and actual customer results; automated results are not customer acceptance.
