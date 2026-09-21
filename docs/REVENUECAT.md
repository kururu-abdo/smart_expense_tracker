# RevenueCat integration

## Identity and products

The mobile SDK is configured after authentication using `user.id` (a stable UUID returned by FastAPI). Never use an email address or let a user choose the RevenueCat identifier. SDK login changes identity when accounts change; logout clears the local identity. Demo mode cannot buy or restore.

Use entitlement ID `premium`. Example store product IDs are `masar_premium_monthly` and `masar_premium_yearly`; create these in your own store accounts, then import them and attach them to the entitlement. Configure a current offering with monthly and annual packages. These names are setup suggestions, not pre-existing products. The client supports whichever packages the current offering supplies.

The app reads each product's localized price from RevenueCat. It does not assume a currency, price, discount, or free trial. Subscription renewal information, restore, and privacy/terms links are included in the paywall. Provide HTTPS `PRIVACY_URL` and `TERMS_URL` before purchase is enabled.

RevenueCat manages App Store / Google Play purchase validation and subscription state. It is not an independent card processor. Store agreements, banking/tax onboarding, product approval and signing remain in your own store accounts.

## Configuration

**Client:** `REVENUECAT_IOS_KEY`, `REVENUECAT_ANDROID_KEY` contain platform-specific public SDK keys only. `config.json` is ignored by git.

**Server:** `REVENUECAT_SECRET_KEY` must authorize the RevenueCat v1 `GET /subscribers/{app_user_id}` endpoint. Do not put it in Flutter. `REVENUECAT_WEBHOOK_AUTHORIZATION` contains the exact header value configured in the dashboard, for example `Bearer <random secret>`.

Optional HMAC: set `REVENUECAT_SIGNING_SECRET` to the integration's signing secret. The handler verifies `X-RevenueCat-Webhook-Signature` over the raw body, including a five-minute timestamp tolerance. Keep clocks synchronized. Header authorization remains required even with HMAC enabled.

Webhook URL: `POST /api/v1/billing/webhook`. Configure all lifecycle events, including transfers, renewals, cancellations, expiration, billing issues and refunds. The handler collects affected UUIDs and fetches canonical subscriber state, rather than inferring access from event types.

`POST /api/v1/billing/sync` is authenticated and accepts no customer ID. It refreshes only the current user's entitlement after a purchase/restore, or when the user taps Refresh subscription. A failed server sync never marks a purchase as failed or invites another charge; the UI displays a pending message.

## Server entitlement policy

- Access is active only if the entitlement is present and its expiration/grace date is in the future, or it is a verified non-expiring entitlement.
- Subscription/non-subscription records must prove a production purchase unless sandbox is explicitly allowed.
- Expiration is checked on every protected request. Positive entitlement snapshots are reconciled after one hour by default; provider failures then fail closed. Refunds/transfers normally arrive through webhooks sooner. A missed webhook can leave access until that cache window ends; reduce `ENTITLEMENT_CACHE_SECONDS` if desired.
- Older canonical snapshots cannot overwrite a newer provider request timestamp. User row locking serializes concurrent refreshes on PostgreSQL.
- Successfully processed event IDs are persisted. Failed processing is not acknowledged as success, so RevenueCat can retry.
- Sandbox notifications are ignored on production. A development backend may set `REVENUECAT_ALLOW_SANDBOX=true`; production configuration rejects this setting.
- Transfer events refresh both source and destination users found in this backend.
- Webhook processing is synchronous and bounded to four known accounts. Large/high-volume projects should move reconciliation to a durable worker queue with persisted retries.

Configure RevenueCat's restore transfer behavior to match your account policy. Review store account switching and restore behavior carefully before launch.

## Sandbox acceptance

1. Register two distinct app accounts; confirm purchases use their backend UUIDs.
2. Subscribe as account A; confirm the store price/period and unlock after server verification.
3. Restore as A on a second device; confirm the entitlement.
4. Cancel; access should remain through the paid period, then expire.
5. Test billing grace period and refund; check backend access.
6. Switch to B; A's cached SDK state must not unlock B.
7. Test configured purchase-transfer behavior, including source revocation.
8. Deliver duplicate webhooks and older notifications; confirm safe reconciliation.
9. Simulate server/provider outage after a successful store purchase; use Refresh subscription when service returns.
10. Verify production ignores sandbox subscriptions, and release builds reject Test Store public keys.

## Official references

- [Flutter SDK installation](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [SDK configuration](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
- [Customer identification](https://www.revenuecat.com/docs/customers/identifying-customers)
- [Making purchases](https://www.revenuecat.com/docs/getting-started/making-purchases)
- [Webhook authorization and synchronization](https://www.revenuecat.com/docs/integrations/webhooks)
