from functools import lru_cache
from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    environment: Literal["development", "production", "test"] = "development"
    database_url: str = "sqlite:///./masar.db"
    jwt_secret: str = Field(min_length=32)
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]
    revenuecat_secret_key: str = ""
    revenuecat_webhook_authorization: str = ""
    revenuecat_signing_secret: str = ""
    revenuecat_entitlement: str = "premium"
    revenuecat_allow_sandbox: bool = False
    entitlement_cache_seconds: int = 3600

    @model_validator(mode="after")
    def production_configuration(self):
        if self.environment == "production":
            if self.database_url.startswith("sqlite"):
                raise ValueError("Production requires PostgreSQL")
            if self.jwt_secret.startswith("change-me"):
                raise ValueError("Generate a unique JWT_SECRET")
            if any(not origin.startswith("https://") for origin in self.cors_origins):
                raise ValueError("Production CORS origins must use HTTPS")
            if self.revenuecat_allow_sandbox:
                raise ValueError("Sandbox purchases must not unlock production")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
