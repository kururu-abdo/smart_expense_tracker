import csv
import io
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Budget, Transaction, User
from app.schemas import BudgetInput, SmartInput, TransactionInput, TransactionOut
from app.security import get_user
from app.services.billing import require_premium
from app.services.money import month_bounds, smart_parse, summarize

router = APIRouter(tags=["Expenses"])


def monthly_query(user: User, month: str):
    start, end = month_bounds(month)
    return select(Transaction).where(
        Transaction.user_id == user.id, Transaction.occurred_on >= start, Transaction.occurred_on < end
    )


def owned(db: Session, model, item_id: str, user: User):
    row = db.scalar(select(model).where(model.id == item_id, model.user_id == user.id))
    if not row:
        raise HTTPException(404, "not_found")
    return row


@router.get("/transactions")
def transactions(
    month: str,
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    q: str = Query("", max_length=100),
    user: User = Depends(get_user),
    db: Session = Depends(get_db),
):
    query = monthly_query(user, month)
    if q:
        query = query.where(Transaction.note.icontains(q, autoescape=True))
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    rows = db.scalars(
        query.order_by(Transaction.occurred_on.desc(), Transaction.created_at.desc(), Transaction.id)
        .offset(offset)
        .limit(limit)
    ).all()
    return {
        "items": [TransactionOut.model_validate(row) for row in rows],
        "total": total,
        "offset": offset,
        "limit": limit,
    }


@router.post("/transactions", response_model=TransactionOut, status_code=201)
def create_transaction(body: TransactionInput, user: User = Depends(get_user), db: Session = Depends(get_db)):
    data = body.model_dump()
    data["client_id"] = str(body.client_id)
    existing = db.scalar(
        select(Transaction).where(Transaction.user_id == user.id, Transaction.client_id == data["client_id"])
    )
    if existing:
        if any(getattr(existing, key) != value for key, value in data.items()):
            raise HTTPException(409, "idempotency_conflict")
        return existing
    row = Transaction(user_id=user.id, **data)
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(
            select(Transaction).where(Transaction.user_id == user.id, Transaction.client_id == data["client_id"])
        )
        if existing and all(getattr(existing, key) == value for key, value in data.items()):
            return existing
        raise HTTPException(409, "idempotency_conflict")
    return row


@router.put("/transactions/{item_id}", response_model=TransactionOut)
def edit_transaction(
    item_id: str, body: TransactionInput, user: User = Depends(get_user), db: Session = Depends(get_db)
):
    row = owned(db, Transaction, item_id, user)
    if str(body.client_id) != row.client_id:
        raise HTTPException(409, "idempotency_conflict")
    for key, value in body.model_dump(exclude={"client_id"}).items():
        setattr(row, key, value)
    db.commit()
    return row


@router.delete("/transactions/{item_id}", status_code=204)
def delete_transaction(item_id: str, user: User = Depends(get_user), db: Session = Depends(get_db)):
    db.delete(owned(db, Transaction, item_id, user))
    db.commit()


@router.get("/overview")
def overview(month: str, user: User = Depends(get_user), db: Session = Depends(get_db)):
    rows = db.scalars(monthly_query(user, month)).all()
    return {**summarize(rows, month), "currency": user.currency, "transaction_count": len(rows)}


@router.post("/smart/parse")
def parse_transaction(body: SmartInput, user: User = Depends(get_user)):
    return smart_parse(body.text)


@router.get("/budgets")
def budgets(month: str, user: User = Depends(get_user), db: Session = Depends(get_db)):
    rows = db.scalars(monthly_query(user, month)).all()
    totals = summarize(rows, month)["categories"]
    budgets = db.scalars(
        select(Budget).where(Budget.user_id == user.id, Budget.month == month).order_by(Budget.category)
    ).all()
    return [
        {
            "id": b.id,
            "month": b.month,
            "category": b.category,
            "limit_minor": b.limit_minor,
            "spent_minor": totals.get(b.category, 0),
        }
        for b in budgets
    ]


@router.put("/budgets")
def set_budget(body: BudgetInput, user: User = Depends(get_user), db: Session = Depends(get_db)):
    month_bounds(body.month)
    db.scalar(select(User).where(User.id == user.id).with_for_update())
    existing = db.scalar(
        select(Budget).where(Budget.user_id == user.id, Budget.month == body.month, Budget.category == body.category)
    )
    if existing:
        existing.limit_minor = body.limit_minor
    else:
        count = db.scalar(
            select(func.count()).select_from(Budget).where(Budget.user_id == user.id, Budget.month == body.month)
        )
        if count >= 3:
            require_premium(db, user)
            # Reacquire after entitlement reconciliation, which may commit.
            db.scalar(select(User).where(User.id == user.id).with_for_update())
        existing = Budget(user_id=user.id, **body.model_dump())
        db.add(existing)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "budget_conflict")
    return {"id": existing.id, **body.model_dump()}


@router.delete("/budgets/{item_id}", status_code=204)
def delete_budget(item_id: str, user: User = Depends(get_user), db: Session = Depends(get_db)):
    db.delete(owned(db, Budget, item_id, user))
    db.commit()


@router.get("/insights")
def insights(month: str, user: User = Depends(get_user), db: Session = Depends(get_db)):
    require_premium(db, user)
    rows = db.scalars(monthly_query(user, month)).all()
    summary = summarize(rows, month)
    start, end = month_bounds(month)
    today = date.today()
    days = (end - start).days
    elapsed = min(days, max(0, (today - start).days + 1))
    actual_spend = sum(row.amount_minor for row in rows if row.kind == "expense" and row.occurred_on <= today)
    projected = round(actual_spend * days / elapsed) if elapsed else 0
    largest = next(iter(summary["categories"]), None)
    return {
        "month": month,
        "method": "rules",
        "currency": user.currency,
        "projected_expense_minor": projected,
        "daily_average_minor": round(actual_spend / elapsed) if elapsed else 0,
        "top_category": largest,
        "top_category_share": round(summary["categories"][largest] / summary["expense_minor"] * 100) if largest else 0,
        "expense_count": sum(row.kind == "expense" for row in rows),
        "has_data": bool(rows),
        "is_projection": start <= today < end,
    }


def csv_safe(value: str) -> str:
    return "'" + value if value.lstrip().startswith(("=", "+", "-", "@", "\t", "\r", "\n")) else value


@router.get("/export.csv")
def export(month: str, user: User = Depends(get_user), db: Session = Depends(get_db)):
    require_premium(db, user)
    rows = db.scalars(monthly_query(user, month).order_by(Transaction.occurred_on, Transaction.id).limit(10001)).all()
    if len(rows) > 10000:
        raise HTTPException(413, "export_too_large")
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["date", "kind", "category", "amount", "currency", "note"])
    for row in rows:
        writer.writerow(
            [
                row.occurred_on.isoformat(),
                row.kind,
                row.category,
                f"{row.amount_minor // 100}.{row.amount_minor % 100:02d}",
                user.currency,
                csv_safe(row.note),
            ]
        )
    return Response(
        "\ufeff" + output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="masar-{month}.csv"'},
    )
