import time
import uuid
from datetime import date

from sqlalchemy import BigInteger, Boolean, CheckConstraint, Date, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def uid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    email: Mapped[str] = mapped_column(String(254), unique=True)
    name: Mapped[str] = mapped_column(String(80))
    password_hash: Mapped[str] = mapped_column(String(255))
    currency: Mapped[str] = mapped_column(String(3), default="SAR")
    locale: Mapped[str] = mapped_column(String(2), default="en")
    premium: Mapped[bool] = mapped_column(Boolean, default=False)
    premium_expires_ms: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    rc_snapshot_ms: Mapped[int] = mapped_column(BigInteger, default=0)
    entitlement_checked_at: Mapped[int] = mapped_column(BigInteger, default=0)


class SessionToken(Base):
    __tablename__ = "sessions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    family_id: Mapped[str] = mapped_column(String(36), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[int] = mapped_column(BigInteger)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint("amount_minor > 0 AND amount_minor <= 1000000000000"),
        CheckConstraint("kind IN ('expense', 'income')"),
        UniqueConstraint("user_id", "client_id"),
        Index("ix_transactions_user_date", "user_id", "occurred_on"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    client_id: Mapped[str] = mapped_column(String(36))
    amount_minor: Mapped[int] = mapped_column(BigInteger)
    kind: Mapped[str] = mapped_column(String(7))
    category: Mapped[str] = mapped_column(String(24))
    note: Mapped[str] = mapped_column(String(240), default="")
    occurred_on: Mapped[date] = mapped_column(Date)
    created_at: Mapped[int] = mapped_column(BigInteger, default=lambda: int(time.time()))


class Budget(Base):
    __tablename__ = "budgets"
    __table_args__ = (
        UniqueConstraint("user_id", "month", "category"),
        CheckConstraint("limit_minor > 0 AND limit_minor <= 1000000000000"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    month: Mapped[str] = mapped_column(String(7))
    category: Mapped[str] = mapped_column(String(24))
    limit_minor: Mapped[int] = mapped_column(BigInteger)


class WebhookEvent(Base):
    __tablename__ = "webhook_events"
    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    received_at: Mapped[int] = mapped_column(BigInteger, default=lambda: int(time.time()))
