import calendar
import re
from collections import defaultdict
from datetime import date
from decimal import Decimal, InvalidOperation

from fastapi import HTTPException

CATEGORIES = {
    "food": ["coffee", "restaurant", "cafe", "lunch", "dinner", "breakfast", "قهوة", "مطعم", "غداء", "عشاء", "فطور"],
    "groceries": ["grocery", "groceries", "supermarket", "بقالة", "سوبرماركت", "تموين", "بنده"],
    "transport": ["uber", "taxi", "fuel", "petrol", "gas", "أوبر", "اوبر", "بنزين", "وقود", "تاكسي"],
    "shopping": ["shopping", "clothes", "amazon", "تسوق", "ملابس", "أمازون"],
    "bills": ["rent", "electricity", "internet", "phone", "إيجار", "ايجار", "كهرباء", "انترنت", "فاتورة"],
    "health": ["pharmacy", "doctor", "hospital", "صيدلية", "طبيب", "مستشفى", "دواء"],
    "entertainment": ["cinema", "movie", "netflix", "سينما", "ترفيه", "نتفلكس"],
}


def month_bounds(month: str):
    try:
        start = date.fromisoformat(month + "-01")
        if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", month) or start.year >= 9999:
            raise ValueError()
    except ValueError:
        raise HTTPException(422, "invalid_month")
    end = date(start.year + (start.month == 12), start.month % 12 + 1, 1)
    return start, end


def summarize(rows, month: str):
    start, _ = month_bounds(month)
    days = calendar.monthrange(start.year, start.month)[1]
    income, expense = 0, 0
    categories = defaultdict(int)
    daily = [0] * days
    for row in rows:
        if row.kind == "income":
            income += row.amount_minor
        else:
            expense += row.amount_minor
            categories[row.category] += row.amount_minor
            daily[row.occurred_on.day - 1] += row.amount_minor
    return {
        "month": month,
        "income_minor": income,
        "expense_minor": expense,
        "balance_minor": income - expense,
        "categories": dict(sorted(categories.items(), key=lambda item: -item[1])),
        "daily_minor": daily,
    }


def smart_parse(text: str):
    normalized = text.translate(str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹٫", "01234567890123456789.")).lower()
    # Grouped thousands and multiple numbers are deliberately rejected: user confirms every suggestion.
    matches = re.findall(r"(?<![\w.])[0-9]+(?:\.[0-9]{1,2})?(?![\d.])", normalized)
    amount = None
    if len(matches) == 1 and not re.search(r"\d[,٬]\d", normalized) and not re.search(r"-\s*\d", normalized):
        try:
            parsed = Decimal(matches[0]) * 100
            if 0 < parsed <= 10**12:
                amount = int(parsed)
        except InvalidOperation:
            pass
    salary = any(x in normalized for x in ["salary", "راتب", "مرتب"])
    category = (
        "salary"
        if salary
        else next((key for key, words in CATEGORIES.items() if any(w in normalized for w in words)), "other")
    )
    return {
        "amount_minor": amount,
        "category": category,
        "kind": "income" if salary else "expense",
        "note": text,
        "needs_confirmation": True,
        "method": "rules",
    }
