"""Tests for the COFLY_REGISTRATION_TOKEN mechanism."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
import models  # noqa: F401 — ensure tables are registered with Base
from main import app


def _make_db():
    """Create a fresh in-memory DB (shared single connection) and return a sessionmaker."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine)


@pytest.fixture()
def client_open(monkeypatch):
    """Client with open registration (no token)."""
    import config, auth
    monkeypatch.setattr(config, "REGISTRATION_TOKEN", "")
    monkeypatch.setattr(auth, "REGISTRATION_TOKEN", "")

    TestSession = _make_db()

    def override_db():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_db
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


@pytest.fixture()
def client_restricted(monkeypatch):
    """Client with registration token = 'secret123'."""
    import config, auth
    monkeypatch.setattr(config, "REGISTRATION_TOKEN", "secret123")
    monkeypatch.setattr(auth, "REGISTRATION_TOKEN", "secret123")

    TestSession = _make_db()

    def override_db():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_db
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


# ── Open registration (backward compat) ──


def test_register_open(client_open):
    r = client_open.post("/cofly/register", json={"username": "u1", "password": "p1"})
    assert r.json()["code"] == 0


def test_get_token_auto_create_open(client_open):
    r = client_open.post("/open-apis/auth/v3/tenant_access_token/internal",
                         json={"app_id": "bot1", "app_secret": "s1"})
    assert r.json()["code"] == 0
    assert r.json()["tenant_access_token"]


def test_ws_endpoint_auto_create_open(client_open):
    r = client_open.post("/callback/ws/endpoint", json={"AppID": "wsbot1", "AppSecret": "s1"})
    assert r.json()["code"] == 0
    assert "URL" in r.json()["data"]


# ── Restricted registration ──


def test_register_no_token_rejected(client_restricted):
    r = client_restricted.post("/cofly/register", json={"username": "u1", "password": "p1"})
    body = r.json()
    assert body["code"] == 1
    assert "invalid registration token" in body["msg"]


def test_register_wrong_token_rejected(client_restricted):
    r = client_restricted.post("/cofly/register",
                               json={"username": "u1", "password": "p1", "registration_token": "wrong"})
    body = r.json()
    assert body["code"] == 1
    assert "invalid registration token" in body["msg"]


def test_register_correct_token_ok(client_restricted):
    r = client_restricted.post("/cofly/register",
                               json={"username": "u1", "password": "p1", "registration_token": "secret123"})
    assert r.json()["code"] == 0


def test_get_token_auto_create_blocked(client_restricted):
    r = client_restricted.post("/open-apis/auth/v3/tenant_access_token/internal",
                               json={"app_id": "newbot", "app_secret": "s1"})
    body = r.json()
    assert body["code"] == 1
    assert "not registered" in body["msg"]


def test_get_token_existing_user_ok(client_restricted):
    """Already registered users can still get tokens."""
    client_restricted.post("/cofly/register",
                           json={"username": "existbot", "password": "pw", "registration_token": "secret123"})
    r = client_restricted.post("/open-apis/auth/v3/tenant_access_token/internal",
                               json={"app_id": "existbot", "app_secret": "pw"})
    assert r.json()["code"] == 0
    assert r.json()["tenant_access_token"]


def test_ws_endpoint_auto_create_blocked(client_restricted):
    r = client_restricted.post("/callback/ws/endpoint", json={"AppID": "newbot2", "AppSecret": "s1"})
    body = r.json()
    assert body["code"] == 1
    assert "not registered" in body["msg"]


def test_ws_endpoint_existing_user_ok(client_restricted):
    """Already registered users can still use ws endpoint."""
    client_restricted.post("/cofly/register",
                           json={"username": "wsbot", "password": "pw", "registration_token": "secret123"})
    r = client_restricted.post("/callback/ws/endpoint", json={"AppID": "wsbot", "AppSecret": "pw"})
    assert r.json()["code"] == 0
    assert "URL" in r.json()["data"]
