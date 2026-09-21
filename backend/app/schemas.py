from datetime import date
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

ExpenseCategory = Literal["food", "groceries", "transport", "shopping", "bills", "health", "entertainment", "other"]
Category = Literal["food", "groceries", "transport", "shopping", "bills", "health", "entertainment", "other", "salary"]
Currency = Literal["SAR", "USD", "AED", "EGP"]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class Register(StrictModel):
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)
    name: str = Field(min_length=1, max_length=80)
    currency: Currency = "SAR"
    locale: Literal["ar", "en"] = "en"


class Login(StrictModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class Refresh(StrictModel):
    refresh_token: str = Field(min_length=30, max_length=256)


class DeleteAccount(StrictModel):
    password: str = Field(min_length=1, max_length=128)


class ProfileUpdate(StrictModel):
    name: str = Field(min_length=1, max_length=80)
    locale: Literal["ar", "en"]


class TransactionInput(StrictModel):
    client_id: UUID
    amount_minor: int = Field(gt=0, le=10**12, strict=True)
    kind: Literal["expense", "income"]
    category: Category
    note: str = Field(default="", max_length=240)
    occurred_on: date

    @field_validator("occurred_on")
    @classmethod
    def supported_date(cls, value):
        if not date(2000, 1, 1) <= value <= date(2100, 1, 1):
            raise ValueError("Date must be between 2000-01-01 and 2100-01-01")
        return value

    @model_validator(mode="after")
    def category_matches_kind(self):
        if self.kind == "expense" and self.category == "salary":
            raise ValueError("Salary is an income category")
        if self.kind == "income" and self.category not in ("salary", "other"):
            raise ValueError("Income category must be salary or other")
        return self


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    client_id: str
    amount_minor: int
    kind: str
    category: str
    note: str
    occurred_on: date


class BudgetInput(StrictModel):
    month: str = Field(pattern=r"^\d{4}-(0[1-9]|1[0-2])$")
    category: ExpenseCategory
    limit_minor: int = Field(gt=0, le=10**12, strict=True)

    @field_validator("month")
    @classmethod
    def valid_month(cls, value):
        date.fromisoformat(value + "-01")
        return value


class SmartInput(StrictModel):
    text: str = Field(min_length=1, max_length=240)
