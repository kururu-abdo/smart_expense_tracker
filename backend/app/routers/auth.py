import time

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import SessionToken, User
from app.schemas import DeleteAccount, Login, ProfileUpdate, Refresh, Register
from app.security import dummy_hash, get_user, issue_tokens, passwords, public_user, throttle, token_hash

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", status_code=201, dependencies=[Depends(throttle)])
def register(body: Register, db: Session = Depends(get_db)):
    user = User(
        email=str(body.email).lower(),
        name=body.name,
        password_hash=passwords.hash(body.password),
        currency=body.currency,
        locale=body.locale,
    )
    db.add(user)
    try:
        db.flush()
        tokens = issue_tokens(db, user)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "email_unavailable")
    return {**tokens, "user": public_user(user)}


@router.post("/login", dependencies=[Depends(throttle)])
def login(body: Login, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == str(body.email).lower()))
    valid = passwords.verify(body.password, user.password_hash if user else dummy_hash)
    if not user or not valid:
        raise HTTPException(401, "invalid_credentials")
    tokens = issue_tokens(db, user)
    db.commit()
    return {**tokens, "user": public_user(user)}


@router.post("/refresh", dependencies=[Depends(throttle)])
def refresh(body: Refresh, db: Session = Depends(get_db)):
    old = db.scalar(
        select(SessionToken).where(SessionToken.token_hash == token_hash(body.refresh_token)).with_for_update()
    )
    if not old or old.expires_at <= time.time():
        raise HTTPException(401, "session_expired")
    if old.revoked:
        db.execute(update(SessionToken).where(SessionToken.family_id == old.family_id).values(revoked=True))
        db.commit()
        raise HTTPException(401, "session_expired")
    old.revoked = True
    user = db.get(User, old.user_id)
    tokens = issue_tokens(db, user, old.family_id)
    db.commit()
    return tokens


@router.post("/logout", status_code=204)
def logout(body: Refresh, user: User = Depends(get_user), db: Session = Depends(get_db)):
    session = db.scalar(
        select(SessionToken).where(
            SessionToken.token_hash == token_hash(body.refresh_token), SessionToken.user_id == user.id
        )
    )
    if session:
        db.execute(update(SessionToken).where(SessionToken.family_id == session.family_id).values(revoked=True))
        db.commit()


@router.get("/me")
def me(user: User = Depends(get_user)):
    return public_user(user)


@router.patch("/me")
def profile(body: ProfileUpdate, user: User = Depends(get_user), db: Session = Depends(get_db)):
    user.name, user.locale = body.name, body.locale
    db.commit()
    return public_user(user)


@router.delete("/me", status_code=204, dependencies=[Depends(throttle)])
def delete_account(body: DeleteAccount, user: User = Depends(get_user), db: Session = Depends(get_db)):
    if not passwords.verify(body.password, user.password_hash):
        raise HTTPException(401, "invalid_credentials")
    db.execute(delete(User).where(User.id == user.id))
    db.commit()
