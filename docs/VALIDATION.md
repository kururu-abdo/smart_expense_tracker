# Validation

Validated on 21 September 2026 using Python 3.12.14 and Flutter 3.35.4 / Dart 3.9.2.

| Check | Result |
| --- | --- |
| FastAPI tests on SQLite | 31 passed |
| Ruff, backend and migrations | Passed |
| SQLite Alembic upgrade and model drift check | Passed |
| Flutter static analysis | No issues |
| Flutter unit and widget tests | 11 passed |
| Flutter release web build | Passed |
| English, Arabic RTL, dark tablet screenshots | Rendered from Flutter and visually reviewed |

The tests cover authentication and refresh-token replay, account isolation,
integer-money accounting, idempotent writes, free/premium boundaries, CSV safety,
Arabic smart entry, RevenueCat webhook authentication and retries, expiration,
transfer reconciliation, concurrent client refresh, logout isolation, responsive
layouts, and entering an expense through the UI.

The screenshots use explicitly labeled demo records. Payment verification tests
use mocked provider responses; they do not demonstrate a completed store purchase.

GitHub Actions also runs the backend suite and migration checks against PostgreSQL.
Its current status is available in the repository's Actions tab. Local SQLite
results are not a substitute for that PostgreSQL job.

Still requiring your deployment/accounts/devices: Android and iOS native release
builds and signing, physical-device testing, App Store / Google Play sandbox
purchases and restores, production hosting, legal URLs, and RevenueCat/store keys.
See [REVENUECAT.md](REVENUECAT.md) and [OPERATIONS.md](OPERATIONS.md).
