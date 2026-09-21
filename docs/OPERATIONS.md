# API and operations

## Routes

All account routes are under `/api/v1`; account data requires a Bearer access token.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/auth/register`, `/auth/login` | Create account / obtain session |
| POST | `/auth/refresh` | Rotate the opaque refresh token |
| POST | `/auth/logout` | Revoke the session family |
| GET / PATCH / DELETE | `/auth/me` | Profile / update name+locale / delete with password |
| GET / POST | `/transactions` | Paginated monthly list / idempotent create |
| PUT / DELETE | `/transactions/{id}` | Edit / delete an owned record |
| GET | `/overview?month=YYYY-MM` | Exact monthly income, expense, balance, category and day totals |
| GET / PUT | `/budgets` | List monthly budgets / upsert category limit |
| DELETE | `/budgets/{id}` | Delete an owned budget |
| POST | `/smart/parse` | English/Arabic rules-based suggestion; user must confirm |
| GET | `/insights?month=YYYY-MM` | Premium spending insights |
| GET | `/export.csv?month=YYYY-MM` | Premium CSV export, max 10,000 records |
| GET | `/billing/status` | Current cached access, with expiry applied |
| POST | `/billing/sync` | Verify current account with RevenueCat |
| POST | `/billing/webhook` | Authorized provider events |
| GET | `/health` | Process health |

Dates are local calendar dates supplied by the user, not converted through UTC. Server projections use the server's current date; deploy in the intended operating timezone if your daily cutover should follow a local calendar. Month boundaries are explicit and tested. Text entry deliberately rejects ambiguous/grouped amounts and requires confirmation; it is not general natural-language understanding.

## Deployment

1. Provision a PostgreSQL database and set `DATABASE_URL` with TLS as required by your host.
2. Set `ENVIRONMENT=production`, a cryptographically random `JWT_SECRET`, exact HTTPS `CORS_ORIGINS`, and billing secrets through your host's secret manager.
3. Install `requirements.txt`; run `alembic upgrade head` once as a deployment job.
4. Serve `uvicorn app.main:app --host 0.0.0.0 --port 8000` behind an HTTPS ingress. Configure worker count for your host. Never run reload in production.
5. Set trusted proxy/forwarded IP configuration at the ingress. The built-in limiter deliberately uses the socket peer, not untrusted forwarded headers. Add ingress or Redis-backed rate limits for login, registration, refresh, and expensive endpoints; the included limiter is process-local.
6. Enforce an ingress request body size limit. Monitor API errors, database health, expired subscriptions and webhook failures. Schedule database backups and test restores.
7. Configure a separate RevenueCat sandbox backend. Production refuses sandbox entitlements.
8. Set the Flutter `API_BASE_URL` to the real HTTPS origin and public RevenueCat SDK keys.

## Native release

Android uses `com.kururu.masar`, min SDK 23 and Java 17. Change the application ID if needed before configuring store products. Release builds do not fall back to a debug signing key. Create ignored `mobile/android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, then build an app bundle. Keep signing keys outside git.

iOS uses the generated `com.kururu.masar` project, iOS 13+, and CocoaPods. Open `ios/Runner.xcworkspace` on macOS, choose your team, enable the In-App Purchase capability, and confirm keychain access configuration for your chosen secure-storage setup. Run `flutter pub get` and `pod install` before archive. Test on a real device and TestFlight.

App account deletion removes backend account data and local credentials. It does **not** cancel an App Store/Play subscription; the confirmation tells users to cancel in the store separately. RevenueCat retains provider purchase records under its own retention settings; align those settings and your privacy policy before release.

## Deliberate boundaries

- No Firebase dependency, bank credentials, transaction scraping or card storage.
- No advertising, analytics or third-party tracking added by this app.
- Mobile session secrets use secure storage. Shared preferences hold only theme/locale.
- Browsers are a preview/client target, not the mobile keychain security model; review web token storage and CSP before a public web launch.
- Data access uses explicit ownership predicates, not PostgreSQL RLS.
- SQLite is for local development; quota locking and concurrent refresh behavior depend on PostgreSQL in production.
- Fresh free accounts do not poll RevenueCat on every request. Purchase, restore and Refresh subscription call `/billing/sync`; provider webhooks also update access.
- No email sender is configured. Add verified-email and password-recovery flows before a broad public rollout.
