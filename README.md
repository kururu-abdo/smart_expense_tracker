# Masar · مسار

A smart expense tracker built with **Flutter + Riverpod** and **FastAPI + SQLAlchemy**, in Arabic and English.

An animated teal-and-cream interface, a dark theme, exact money calculations, monthly budgets, and RevenueCat subscriptions. Includes Android, iOS, and web projects. Web is also useful for exploring the interface; subscription checkout is enabled on iOS and Android.

> This branch implements the Flutter/FastAPI app requested in this conversation. The repository's original Kotlin/Bayyinah README is preserved in [BAYYINAH_REFERENCE.md](docs/BAYYINAH_REFERENCE.md); its feature claims describe a separate project, not this implementation.

## Preview

<img src="docs/screenshots/dashboard-en.png" width="260" alt="English dashboard" /> <img src="docs/screenshots/dashboard-ar.png" width="260" alt="Arabic RTL dashboard" />

## Features

| Feature | Free | Premium |
| --- | --- | --- |
| Income and expense tracking, editing, deletion | ✓ | ✓ |
| Monthly overview, category filters and search | ✓ | ✓ |
| English/Arabic smart text suggestions | ✓ | ✓ |
| Arabic RTL, English, light/dark theme | ✓ | ✓ |
| Category budgets per month | 3 | Unlimited |
| Category breakdown and spending projections | — | ✓ |
| CSV export through share/download sheet | — | ✓ |

All premium endpoints enforce access on the server. Demo mode uses temporary sample data, never real account records. Smart entry and spending insights use transparent rules and arithmetic; no LLM key or external AI service is required.

## Quick start

Requirements: Python 3.12+, Flutter 3.35.4 / Dart 3.9.2 or a compatible stable SDK, and the relevant platform SDK. Dependencies resolve into `mobile/pubspec.lock`; CI uses the tested Flutter version.

### 1. Backend

```bash
python3 scripts/init_env.py
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

`init_env.py` creates `backend/.env` with a fresh signing secret and leaves an existing file untouched. Local development uses SQLite and needs no Docker. API documentation: `http://localhost:8000/docs`.

For PostgreSQL, set `DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:5432/masar` in `.env`, then run `alembic upgrade head`. Production requires PostgreSQL, HTTPS, and explicit CORS origins.

### 2. Flutter

```bash
cd mobile
flutter pub get
cp config.example.json config.json
flutter run --dart-define-from-file=config.json
```

Set `API_BASE_URL` in `config.json`:

| Device | Local API URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8000/api/v1` |
| iOS simulator / local web | `http://localhost:8000/api/v1` |
| Physical device | HTTPS development endpoint or your computer's LAN address on the same network |
| Release app | Your deployed HTTPS API ending in `/api/v1` |

Android debug builds allow local HTTP. Release builds require HTTPS in Dart and do not enable cleartext traffic. On iOS, use an HTTPS development endpoint if ATS blocks local HTTP; do not disable ATS globally for release.

Use **Explore the demo** for a working UI without a backend. Demo records reset when you leave. Authenticated use requires a network connection; offline writes/sync are not implemented.

For a browser preview:

```bash
flutter run -d chrome --web-port 8080 --dart-define-from-file=config.json
```

### 3. RevenueCat

Read [the full RevenueCat setup](docs/REVENUECAT.md). The app runs without purchase keys; checkout stays unavailable until configured.

1. Add iOS and Android apps to your RevenueCat project using your actual bundle/package IDs.
2. Create monthly/yearly subscription products in the stores and import them into RevenueCat.
3. Attach the products to entitlement **`premium`** and a current offering.
4. Add **public** iOS/Android SDK keys and your published privacy/terms URLs to `mobile/config.json`.
5. Add the secret server key and webhook authorization value to `backend/.env`.
6. Point RevenueCat's webhook at `https://YOUR_API/api/v1/billing/webhook`.
7. Test purchases, restore, cancellation, expiration and account switching in sandbox before release.

The authenticated backend UUID is the RevenueCat app user ID. The client never sends a trusted `premium=true` value. Prices come directly from store offerings.

## Architecture

```text
mobile/lib/
  core/          models, API client, repositories, controller, billing, theme, localization
  features/      auth, overview, activity, expense editor, budgets, insights, paywall, settings
backend/
  app/routers/   auth, expenses, billing
  app/services/  exact-money summaries, smart parsing, RevenueCat verification
  alembic/       versioned SQL migrations
  tests/         authentication, ownership, accounting and billing tests
```

The Riverpod controller acts as a view model over repository contracts. Widgets never call HTTP directly. The remote repository and in-memory demo repository implement the same contract.

- Money is stored as integer minor units. Supported account currencies are SAR, USD, AED, EGP (2 decimal places). Account currency is fixed; no mixed-currency summing or exchange-rate conversion.
- Auth uses Argon2 passwords, short-lived JWT access tokens, hashed rotating refresh tokens, session revocation, and token-family revocation on replay.
- Transactions carry a per-account UUID idempotency key, preventing duplicate creates on retry.
- Every data query is scoped to the authenticated user. PostgreSQL row locks serialize quota checks and subscription refreshes.
- Webhooks authenticate, optionally verify HMAC, deduplicate event IDs, and reconcile canonical subscriber status including transfers.
- Financial CSV cells are escaped against spreadsheet formula injection.

See [API and operations](docs/OPERATIONS.md) for endpoints, security boundaries, and release steps.

## Checks

```bash
cd backend
pytest -q
ruff check app tests alembic
alembic upgrade head
alembic check

cd ../mobile
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

To regenerate actual Flutter UI screenshots:

```bash
cd mobile
flutter test test/app_test.dart --dart-define=CAPTURE_SCREENSHOTS=true
```

CI checks Python tests, SQLite/PostgreSQL migrations, Dart analysis, Flutter widget/unit tests, and web compilation. Android/iOS store purchases need physical-device/store sandbox validation and your signing credentials.

See [validation results and remaining device checks](docs/VALIDATION.md).

## Scope of this version

This is a functional v1 implementation. Before public launch, configure deployment, store products and signing, publish your legal pages, add operational monitoring/backups and production rate limits, and complete device purchase testing. Password recovery/email verification, bank feeds, receipt OCR, recurring transactions, offline synchronization and LLM-based coaching are future extensions.
