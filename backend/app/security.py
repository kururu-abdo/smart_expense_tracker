import hashlib
import secrets
import time
from collections import defaultdict, deque
from threading import Lock
from uuid import uuid4

import jwt
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.models import SessionToken, User

passwords = PasswordHash.recommended()
dummy_hash = passwords.hash("not-a-valid-user-password")
bearer = HTTPBearer(auto_error=False)
_attempts: dict[str, deque] = defaultdict(deque)
_attempt_lock = Lock()


def throttle(request: Request):
    # In-process defense for local/single-worker installs. Add edge/Redis rate limits for multi-worker production.
    key = request.client.host if request.client else "unknown"
    now = time.monotonic()
    with _attempt_lock:
        for old in list(_attempts):
            while _attempts[old] and _attempts[old][0] < now - 60:
                _attempts[old].popleft()
            if not _attempts[old]:
                del _attempts[old]
        if len(_attempts[key]) >= 20:
            raise HTTPException(429, "rate_limited", headers={"Retry-After": "60"})
        _attempts[key].append(now)


def token_hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def issue_tokens(db: Session, user: User, family_id: str | None = None) -> dict:
    settings = get_settings()
    now = int(time.time())
    refresh = secrets.token_urlsafe(48)
    session = SessionToken(
        user_id=user.id,
        token_hash=token_hash(refresh),
        family_id=family_id or str(uuid4()),
        expires_at=now + settings.refresh_token_days * 86400,
    )
    db.add(session)
    db.flush()
    access = jwt.encode(
        {
            "sub": user.id,
            "sid": session.id,
            "iat": now,
            "exp": now + settings.access_token_minutes * 60,
            "iss": "masar-api",
            "aud": "masar-mobile",
        },
        settings.jwt_secret,
        algorithm="HS256",
    )
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "expires_in": settings.access_token_minutes * 60,
    }


def get_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer), db: Session = Depends(get_db)) -> User:
    unauthorized = HTTPException(401, "session_expired", headers={"WWW-Authenticate": "Bearer"})
    if not credentials:
        raise unauthorized
    try:
        payload = jwt.decode(
            credentials.credentials,
            get_settings().jwt_secret,
            algorithms=["HS256"],
            issuer="masar-api",
            audience="masar-mobile",
            options={"require": ["exp", "iat", "sub", "sid"]},
        )
    except jwt.PyJWTError:
        raise unauthorized
    session = db.get(SessionToken, payload["sid"])
    if not session or session.revoked or session.expires_at <= time.time() or session.user_id != payload["sub"]:
        raise unauthorized
    user = db.scalar(select(User).where(User.id == payload["sub"]))
    if not user:
        raise unauthorized
    return user


def public_user(user: User) -> dict:
    return {"id": user.id, "email": user.email, "name": user.name, "currency": user.currency, "locale": user.locale}
