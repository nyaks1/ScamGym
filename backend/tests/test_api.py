"""HTTP contract tests. Gemini is stubbed so the suite stays offline."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import app.api as api_module
from app.main import app


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    async def no_explanation(kind: str, report: dict) -> None:
        return None

    monkeypatch.setattr(api_module.gemini, "explain_triage", no_explanation)
    return TestClient(app)


def test_health_reports_the_model_and_scenario_count(client: TestClient) -> None:
    response = client.get("/api/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["scenarios"] == 5
    assert isinstance(body["ai"], bool)


def test_security_headers_are_set(client: TestClient) -> None:
    response = client.get("/api/health")
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert "default-src 'self'" in response.headers["content-security-policy"]


def test_scenarios_do_not_leak_red_flags(client: TestClient) -> None:
    response = client.get("/api/scenarios")
    assert response.status_code == 200
    scenarios = response.json()["scenarios"]
    assert len(scenarios) == 5
    for scenario in scenarios:
        assert "red_flags" not in scenario
        assert "persona" not in scenario


def test_check_link_returns_the_deterministic_verdict(client: TestClient) -> None:
    response = client.post("/api/check/link", json={"url": "https://paypa1.com/login"})
    assert response.status_code == 200
    body = response.json()
    assert body["verdict"] in {"high", "critical"}
    assert body["ai_explanation"] is None
    assert any(finding["id"] == "brand_lookalike" for finding in body["findings"])


def test_check_message_returns_links_and_advice(client: TestClient) -> None:
    response = client.post(
        "/api/check/message",
        json={"text": "Verify your account: https://paypa1.com/login"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["links"]
    assert body["advice"]
    assert body["verdict"] in {"high", "critical"}


def test_check_rejects_empty_input(client: TestClient) -> None:
    assert client.post("/api/check/link", json={"url": ""}).status_code == 422
    assert client.post("/api/check/message", json={"text": ""}).status_code == 422


def test_round_lifecycle_without_ai(client: TestClient) -> None:
    created = client.post("/api/rounds", json={"scenario_id": "parcelpal"})
    assert created.status_code == 201
    body = created.json()
    round_id = body["round_id"]
    assert body["opening"]
    assert body["status"] == "active"

    event = client.post(
        f"/api/rounds/{round_id}/events",
        json={"kind": "link_clicked", "url": "https://parcelpal-fees.example.com/pay"},
    )
    assert event.status_code == 200
    assert event.json()["recorded"] == "clicked_link"

    scored = client.post(f"/api/rounds/{round_id}/score")
    assert scored.status_code == 200
    score = scored.json()
    assert 0 <= score["score"] <= 100
    assert any(action["kind"] == "clicked_link" for action in score["actions"])

    assert client.delete(f"/api/rounds/{round_id}").status_code == 204
    assert client.get(f"/api/rounds/{round_id}").status_code == 404


def test_unknown_scenario_is_404(client: TestClient) -> None:
    assert client.post("/api/rounds", json={"scenario_id": "nope"}).status_code == 404


def test_send_without_gemini_returns_503_and_rolls_back(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    created = client.post("/api/rounds", json={"scenario_id": "kalahari-bank"})
    round_id = created.json()["round_id"]

    monkeypatch.setattr(api_module.trainer.gemini, "_client", None)

    response = client.post(f"/api/rounds/{round_id}/messages", json={"text": "Hello?"})
    assert response.status_code == 503

    state = client.get(f"/api/rounds/{round_id}").json()
    assert state["turn"] == 0
    assert all(item["role"] != "user" for item in state["transcript"])


def test_events_are_rejected_after_the_round_is_scored(client: TestClient) -> None:
    round_id = client.post("/api/rounds", json={"scenario_id": "parcelpal"}).json()["round_id"]
    assert client.post(f"/api/rounds/{round_id}/score").status_code == 200

    response = client.post(
        f"/api/rounds/{round_id}/events",
        json={"kind": "link_clicked", "url": "https://example.com/x"},
    )
    assert response.status_code == 409
