import time
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.config import get_settings
from app.models import SessionToken, User
from app.services.money import smart_parse

API = "/api/v1"


def transaction(**changes):
    return {
        "client_id": str(uuid4()),
        "amount_minor": 2590,
        "kind": "expense",
        "category": "food",
        "note": "Coffee",
        "occurred_on": "2026-09-12",
        **changes,
    }


def premium(db_factory, user_id, expires=None):
    with db_factory() as db:
        user = db.get(User, user_id)
        user.premium = True
        user.premium_expires_ms = expires or int(time.time() * 1000) + 86400000
        user.entitlement_checked_at = int(time.time())
        db.commit()


def test_auth_rotation_and_replay_revoke_family(client, account):
    data, headers = account
    assert client.get(API + "/auth/me", headers=headers).status_code == 200
    renewed = client.post(API + "/auth/refresh", json={"refresh_token": data["refresh_token"]})
    assert renewed.status_code == 200
    assert client.get(API + "/auth/me", headers=headers).status_code == 401
    assert client.post(API + "/auth/refresh", json={"refresh_token": data["refresh_token"]}).status_code == 401
    new_headers = {"Authorization": "Bearer " + renewed.json()["access_token"]}
    assert client.get(API + "/auth/me", headers=new_headers).status_code == 401


def test_logout_revokes_access(client, account):
    data, headers = account
    assert (
        client.post(API + "/auth/logout", headers=headers, json={"refresh_token": data["refresh_token"]}).status_code
        == 204
    )
    assert client.get(API + "/auth/me", headers=headers).status_code == 401


def test_login_normalizes_email_and_rejects_bad_password(client, account):
    good = client.post(API + "/auth/login", json={"email": "USER@example.com", "password": "correct-horse-123"})
    assert good.status_code == 200
    assert client.post(API + "/auth/login", json={"email": "user@example.com", "password": "wrong"}).status_code == 401


def test_exact_totals_and_idempotency(client, account):
    _, headers = account
    data = transaction(amount_minor=10)
    for _ in range(2):
        assert client.post(API + "/transactions", headers=headers, json=data).status_code == 201
    assert client.post(API + "/transactions", headers=headers, json=transaction(amount_minor=20)).status_code == 201
    conflict = client.post(API + "/transactions", headers=headers, json={**data, "amount_minor": 99})
    assert conflict.status_code == 409
    total = client.get(API + "/overview?month=2026-09", headers=headers).json()
    assert total["expense_minor"] == 30
    assert total["transaction_count"] == 2
    assert total["daily_minor"][11] == 30


@pytest.mark.parametrize("amount", [0, -1, 10**12 + 1, 1.1, True])
def test_invalid_money_rejected(client, account, amount):
    _, headers = account
    assert client.post(API + "/transactions", headers=headers, json=transaction(amount_minor=amount)).status_code == 422


def test_ownership_prevents_cross_account_reads_edits_deletes(client, account):
    _, headers = account
    first = client.post(API + "/transactions", headers=headers, json=transaction()).json()
    second = client.post(
        API + "/auth/register", json={"name": "Other", "email": "other@example.com", "password": "correct-horse-123"}
    ).json()
    other = {"Authorization": "Bearer " + second["access_token"]}
    assert client.get(API + "/transactions?month=2026-09", headers=other).json()["items"] == []
    assert (
        client.put(
            API + "/transactions/" + first["id"], headers=other, json=transaction(client_id=first["client_id"])
        ).status_code
        == 404
    )
    assert client.delete(API + "/transactions/" + first["id"], headers=other).status_code == 404


def test_free_budget_limit_enforced_server_side(client, account, db_factory):
    data, headers = account
    for category in ["food", "transport", "shopping"]:
        assert (
            client.put(
                API + "/budgets", headers=headers, json={"month": "2026-09", "category": category, "limit_minor": 50000}
            ).status_code
            == 200
        )
    fourth = {"month": "2026-09", "category": "bills", "limit_minor": 70000}
    assert client.put(API + "/budgets", headers=headers, json=fourth).status_code == 403
    premium(db_factory, data["user"]["id"])
    assert client.put(API + "/budgets", headers=headers, json=fourth).status_code == 200


def test_expired_subscription_cannot_export(client, account, db_factory):
    data, headers = account
    premium(db_factory, data["user"]["id"], expires=1)
    assert client.get(API + "/export.csv?month=2026-09", headers=headers).status_code == 403
    assert client.get(API + "/billing/status", headers=headers).json()["premium"] is False


def test_export_preserves_decimal_and_escapes_formula(client, account, db_factory):
    data, headers = account
    premium(db_factory, data["user"]["id"])
    client.post(API + "/transactions", headers=headers, json=transaction(amount_minor=101, note='=HYPERLINK("evil")'))
    result = client.get(API + "/export.csv?month=2026-09", headers=headers)
    assert result.status_code == 200
    assert "1.01,SAR" in result.text
    assert "'=HYPERLINK" in result.text


def test_month_boundaries_and_invalid_months(client, account):
    _, headers = account
    client.post(API + "/transactions", headers=headers, json=transaction(occurred_on="2026-10-01"))
    assert client.get(API + "/overview?month=2026-09", headers=headers).json()["expense_minor"] == 0
    assert client.get(API + "/overview?month=2026-13", headers=headers).status_code == 422
    assert client.get(API + "/overview?month=9999-12", headers=headers).status_code == 422


def test_budget_spending_updates_on_transaction_edit(client, account):
    _, headers = account
    row = client.post(API + "/transactions", headers=headers, json=transaction()).json()
    client.put(API + "/budgets", headers=headers, json={"month": "2026-09", "category": "food", "limit_minor": 5000})
    assert client.get(API + "/budgets?month=2026-09", headers=headers).json()[0]["spent_minor"] == 2590
    assert (
        client.put(
            API + "/transactions/" + row["id"],
            headers=headers,
            json=transaction(client_id=row["client_id"], amount_minor=3500),
        ).status_code
        == 200
    )
    assert client.get(API + "/budgets?month=2026-09", headers=headers).json()[0]["spent_minor"] == 3500


def test_delete_account_cascades(client, account, db_factory):
    data, headers = account
    client.post(API + "/transactions", headers=headers, json=transaction())
    response = client.request("DELETE", API + "/auth/me", headers=headers, json={"password": "correct-horse-123"})
    assert response.status_code == 204
    with db_factory() as db:
        assert db.get(User, data["user"]["id"]) is None
        assert db.scalar(select(SessionToken).where(SessionToken.user_id == data["user"]["id"])) is None
    assert client.get(API + "/auth/me", headers=headers).status_code == 401


@pytest.mark.parametrize(
    ("text", "amount", "category"),
    [
        ("قهوة ١٨٫٥٠ ريال", 1850, "food"),
        ("Taxi 25.90", 2590, "transport"),
        ("راتب ٩٠٠٠", 900000, "salary"),
        ("coffee 15 and taxi 20", None, "food"),
        ("coffee 1,500", None, "food"),
        ("coffee -20", None, "food"),
    ],
)
def test_smart_parse(text, amount, category):
    result = smart_parse(text)
    assert result["amount_minor"] == amount
    assert result["category"] == category
    assert result["needs_confirmation"]


def test_webhook_requires_authorization(client, monkeypatch):
    monkeypatch.setattr(get_settings(), "revenuecat_webhook_authorization", "Bearer test-secret")
    assert client.post(API + "/billing/webhook", json={"event": {"id": "x"}}).status_code == 401


def test_webhook_reconciles_and_deduplicates(client, account, monkeypatch):
    data, headers = account
    user_id = data["user"]["id"]
    monkeypatch.setattr(get_settings(), "revenuecat_webhook_authorization", "Bearer test-secret")
    calls = []

    def subscriber(uid):
        calls.append(uid)
        return {
            "request_date_ms": int(time.time() * 1000),
            "subscriber": {
                "entitlements": {"premium": {"product_identifier": "pro", "expires_date": "2099-01-01T00:00:00Z"}},
                "subscriptions": {"pro": {"is_sandbox": False}},
            },
        }

    monkeypatch.setattr("app.services.billing.read_subscriber", subscriber)
    body = {"event": {"id": "evt-1", "app_user_id": user_id, "type": "INITIAL_PURCHASE", "environment": "PRODUCTION"}}
    auth = {"Authorization": "Bearer test-secret"}
    assert client.post(API + "/billing/webhook", headers=auth, json=body).json()["status"] == "processed"
    assert client.post(API + "/billing/webhook", headers=auth, json=body).json()["status"] == "duplicate"
    assert calls == [user_id]
    assert client.get(API + "/billing/status", headers=headers).json()["premium"]


def test_sandbox_subscriber_never_grants_production_access(client, account, monkeypatch):
    _, headers = account
    monkeypatch.setattr(
        "app.services.billing.read_subscriber",
        lambda _: {
            "request_date_ms": int(time.time() * 1000),
            "subscriber": {
                "entitlements": {"premium": {"product_identifier": "pro", "expires_date": None}},
                "subscriptions": {"pro": {"is_sandbox": True}},
            },
        },
    )
    assert client.post(API + "/billing/sync", headers=headers).json()["premium"] is False


def test_client_cannot_grant_premium(client, account):
    _, headers = account
    result = client.patch(API + "/auth/me", headers=headers, json={"name": "Eve", "locale": "en", "premium": True})
    assert result.status_code == 422


def test_missing_billing_key_is_explicit(client, account):
    _, headers = account
    assert client.post(API + "/billing/sync", headers=headers).status_code == 503


def test_webhook_failure_can_retry_without_losing_event(client, account, monkeypatch):
    from fastapi import HTTPException

    data, headers = account
    settings = get_settings()
    monkeypatch.setattr(settings, "revenuecat_webhook_authorization", "Bearer test-secret")

    def unavailable(_):
        raise HTTPException(503, "billing_unavailable")

    monkeypatch.setattr("app.services.billing.read_subscriber", unavailable)
    body = {"event": {"id": "retry-me", "app_user_id": data["user"]["id"], "type": "RENEWAL"}}
    auth = {"Authorization": "Bearer test-secret"}
    assert client.post(API + "/billing/webhook", headers=auth, json=body).status_code == 503
    monkeypatch.setattr(
        "app.services.billing.read_subscriber",
        lambda _: {"request_date_ms": int(time.time() * 1000), "subscriber": {"entitlements": {}}},
    )
    assert client.post(API + "/billing/webhook", headers=auth, json=body).json()["status"] == "processed"


def test_webhook_transfer_refreshes_both_accounts(client, account, db_factory, monkeypatch):
    data, headers = account
    second = client.post(
        API + "/auth/register", json={"name": "Second", "email": "second@example.com", "password": "correct-horse-123"}
    ).json()
    premium(db_factory, data["user"]["id"])
    monkeypatch.setattr(get_settings(), "revenuecat_webhook_authorization", "Bearer test-secret")

    def subscriber(uid):
        return {
            "request_date_ms": int(time.time() * 1000),
            "subscriber": {
                "entitlements": {"premium": {"product_identifier": "pro", "expires_date": "2099-01-01T00:00:00Z"}}
                if uid == second["user"]["id"]
                else {},
                "subscriptions": {"pro": {"is_sandbox": False}},
            },
        }

    monkeypatch.setattr("app.services.billing.read_subscriber", subscriber)
    body = {
        "event": {
            "id": "transfer-1",
            "type": "TRANSFER",
            "transferred_from": [data["user"]["id"]],
            "transferred_to": [second["user"]["id"]],
        }
    }
    assert (
        client.post(API + "/billing/webhook", headers={"Authorization": "Bearer test-secret"}, json=body).status_code
        == 200
    )
    assert client.get(API + "/billing/status", headers=headers).json()["premium"] is False
    assert (
        client.get(API + "/billing/status", headers={"Authorization": "Bearer " + second["access_token"]}).json()[
            "premium"
        ]
        is True
    )


def test_signed_webhook_checks_raw_body_and_timestamp(client, monkeypatch):
    import hashlib
    import hmac

    settings = get_settings()
    monkeypatch.setattr(settings, "revenuecat_webhook_authorization", "Bearer test-secret")
    monkeypatch.setattr(settings, "revenuecat_signing_secret", "signing-test-secret")
    raw = b'{"event":{"id":"signed-test","type":"TEST"}}'
    timestamp = str(int(time.time()))
    signature = hmac.new(b"signing-test-secret", timestamp.encode() + b"." + raw, hashlib.sha256).hexdigest()
    headers = {
        "Authorization": "Bearer test-secret",
        "Content-Type": "application/json",
        "X-RevenueCat-Webhook-Signature": f"t={timestamp},v1={signature}",
    }
    assert client.post(API + "/billing/webhook", headers=headers, content=raw).status_code == 200
    assert client.post(API + "/billing/webhook", headers=headers, content=raw + b" ").status_code == 401


def test_stale_subscriber_snapshot_does_not_regrant_access(client, account, db_factory, monkeypatch):
    data, headers = account
    stamp = int(time.time() * 1000)
    with db_factory() as db:
        user = db.get(User, data["user"]["id"])
        user.premium = False
        user.rc_snapshot_ms = stamp
        db.commit()
    monkeypatch.setattr(
        "app.services.billing.read_subscriber",
        lambda _: {
            "request_date_ms": stamp - 1000,
            "subscriber": {
                "entitlements": {"premium": {"product_identifier": "pro", "expires_date": None}},
                "subscriptions": {"pro": {"is_sandbox": False}},
            },
        },
    )
    assert client.post(API + "/billing/sync", headers=headers).json()["premium"] is False
