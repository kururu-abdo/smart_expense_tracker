import time
from datetime import datetime
from urllib.parse import quote

import httpx
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import User


def is_premium(user: User) -> bool:
    return user.premium and (user.premium_expires_ms is None or user.premium_expires_ms > int(time.time() * 1000))


def read_subscriber(user_id: str) -> dict:
    key = get_settings().revenuecat_secret_key
    if not key:
        raise HTTPException(503, "billing_not_configured")
    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(
                "https://api.revenuecat.com/v1/subscribers/" + quote(user_id, safe=""),
                headers={"Authorization": "Bearer " + key, "Accept": "application/json"},
            )
            response.raise_for_status()
            return response.json()
    except (httpx.HTTPError, ValueError):
        raise HTTPException(503, "billing_unavailable")


def _millis(value: str | None) -> int | None:
    if value is None:
        return None
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1000)


def sync_subscription(db: Session, user: User):
    # Lock before fetching so purchases, webhooks, and transfer refreshes serialize per customer.
    db.scalar(select(User).where(User.id == user.id).with_for_update().execution_options(populate_existing=True))
    data = read_subscriber(user.id)
    try:
        stamp = int(data["request_date_ms"])
        if stamp < user.rc_snapshot_ms:
            return
        subscriber = data["subscriber"]
        entitlement = subscriber.get("entitlements", {}).get(get_settings().revenuecat_entitlement)
        active, expires = False, None
        if entitlement:
            expires = _millis(entitlement["expires_date"])
            grace = _millis(entitlement.get("grace_period_expires_date"))
            if expires is not None and grace is not None:
                expires = max(expires, grace)
            product = entitlement.get("product_identifier")
            subscription = subscriber.get("subscriptions", {}).get(product)
            purchases = subscriber.get("non_subscriptions", {}).get(product, [])
            records = [subscription] if subscription else purchases
            trusted_environment = get_settings().revenuecat_allow_sandbox or any(
                record.get("is_sandbox") is False for record in records
            )
            active = bool(trusted_environment and (expires is None or expires > int(time.time() * 1000)))
        user.premium, user.premium_expires_ms = active, expires
        user.rc_snapshot_ms, user.entitlement_checked_at = stamp, int(time.time())
        db.flush()
    except (KeyError, TypeError, ValueError):
        raise HTTPException(503, "billing_unavailable")


def require_premium(db: Session, user: User):
    if user.premium and int(time.time()) - user.entitlement_checked_at > get_settings().entitlement_cache_seconds:
        sync_subscription(db, user)
        db.commit()
    if not is_premium(user):
        raise HTTPException(403, "premium_required")


def subscription_status(user: User):
    active = is_premium(user)
    return {
        "premium": active,
        "plan": "premium" if active else "free",
        "expires_at_ms": user.premium_expires_ms,
        "free_budget_limit": 3,
    }
