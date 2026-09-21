import hashlib
import hmac
import json
import time

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.config import get_settings
from app.database import get_db
from app.models import User, WebhookEvent
from app.security import get_user, throttle
from app.services.billing import subscription_status, sync_subscription

router = APIRouter(prefix="/billing", tags=["Subscriptions"])


@router.get("/status")
def status(user: User = Depends(get_user)):
    return subscription_status(user)


@router.post("/sync", dependencies=[Depends(throttle)])
def sync(user: User = Depends(get_user), db: Session = Depends(get_db)):
    sync_subscription(db, user)
    db.commit()
    return subscription_status(user)


@router.post("/webhook")
async def webhook(request: Request, db: Session = Depends(get_db)):
    settings = get_settings()
    expected = settings.revenuecat_webhook_authorization
    if not expected:
        raise HTTPException(503, "billing_not_configured")
    if not hmac.compare_digest(request.headers.get("Authorization", ""), expected):
        raise HTTPException(401, "invalid_webhook")
    raw = await request.body()
    if len(raw) > 262144:
        raise HTTPException(413, "payload_too_large")
    if settings.revenuecat_signing_secret:
        try:
            fields = dict(
                part.strip().split("=", 1)
                for part in request.headers.get("X-RevenueCat-Webhook-Signature", "").split(",")
            )
            expected_signature = hmac.new(
                settings.revenuecat_signing_secret.encode(), fields["t"].encode() + b"." + raw, hashlib.sha256
            ).hexdigest()
            valid = hmac.compare_digest(expected_signature, fields["v1"]) and abs(time.time() - int(fields["t"])) <= 300
        except (KeyError, ValueError):
            valid = False
        if not valid:
            raise HTTPException(401, "invalid_webhook_signature")
    try:
        event = json.loads(raw)["event"]
        event_id = event["id"]
        if not isinstance(event_id, str) or not 1 <= len(event_id) <= 128:
            raise ValueError()
    except (KeyError, ValueError, TypeError):
        raise HTTPException(422, "invalid_webhook")
    return await run_in_threadpool(process_event, db, event)


def process_event(db: Session, event: dict):
    settings = get_settings()
    event_id = event["id"]
    if db.get(WebhookEvent, event_id):
        return {"status": "duplicate"}
    if event.get("type") == "TEST" or (event.get("environment") == "SANDBOX" and not settings.revenuecat_allow_sandbox):
        return {"status": "ignored"}
    ids = [event.get("app_user_id"), event.get("original_app_user_id")]
    for key in ["aliases", "transferred_from", "transferred_to"]:
        items = event.get(key, [])
        if isinstance(items, list):
            ids.extend(items[:100])
    ids = sorted({value for value in ids if isinstance(value, str) and len(value) == 36})
    users = db.scalars(select(User).where(User.id.in_(ids)).order_by(User.id)).all()
    # Never trust a payload's premium flag; fetch the canonical subscriber for all affected accounts.
    # Synchronous processing stays below the provider timeout; a worker queue is needed at high volume.
    if len(users) > 4:
        raise HTTPException(503, "webhook_batch_requires_worker")
    for user in users:
        sync_subscription(db, user)
    db.add(WebhookEvent(id=event_id))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        return {"status": "duplicate"}
    return {"status": "processed"}
