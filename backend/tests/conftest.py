import os

os.environ["JWT_SECRET"] = "test-only-key-never-use-in-production-12345678"
os.environ["ENVIRONMENT"] = "test"
os.environ["DATABASE_URL"] = "sqlite://"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.security import _attempts


@pytest.fixture
def db_factory():
    url = os.environ.get("TEST_DATABASE_URL", "sqlite://")
    options = (
        {"connect_args": {"check_same_thread": False}, "poolclass": StaticPool} if url.startswith("sqlite") else {}
    )
    engine = create_engine(url, **options)

    @event.listens_for(engine, "connect")
    def fk(connection, _):
        if engine.dialect.name == "sqlite":
            connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    factory = sessionmaker(engine, expire_on_commit=False)
    yield factory
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def client(db_factory):
    _attempts.clear()

    def override():
        with db_factory() as db:
            yield db

    app.dependency_overrides[get_db] = override
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


@pytest.fixture
def account(client):
    response = client.post(
        "/api/v1/auth/register",
        json={"name": "Test User", "email": "user@example.com", "password": "correct-horse-123"},
    )
    assert response.status_code == 201, response.text
    data = response.json()
    return data, {"Authorization": "Bearer " + data["access_token"]}
