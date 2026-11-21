"""HTTP API.

Every endpoint is same-origin. No CORS is enabled by default: the bundled web
client is served by this server. Add CORS only if you build a separate client.
"""

from __future__ import annotations

import logging
import time
from typing import Literal

from fastapi import APIRouter, HTTPException, Request, Response, status
from pydantic import BaseModel, ConfigDict, Field

from app.config import settings
from app.deps import gemini, trainer
from app.engine.triage_link import analyze_link
from app.engine.triage_message import analyze_message
from app.engine.trainer import AIUnavailableError, RoundConflictError, RoundNotFoundError
from app.scenarios import all_scenarios, get_scenario

logger = logging.getLogger("scamgym.api")
router = APIRouter()


class StartRoundRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    scenario_id: str = Field(min_length=1, max_length=80)


class MessageRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    text: str = Field(min_length=1, max_length=1200)


class ClientEventRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    kind: Literal["link_clicked"]
    url: str = Field(min_length=1, max_length=2048)


class LinkCheckRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    url: str = Field(min_length=1, max_length=2048)


class MessageCheckRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    text: str = Field(min_length=1, max_length=5000)


class FixedWindowLimiter:
    """Small in-memory limiter; no Redis, no persistence."""

    def __init__(self, limit: int, window_seconds: int = 60):
        self.limit = limit
        self.window_seconds = window_seconds
        self._hits: dict[str, tuple[float, int]] = {}

    def allow(self, key: str) -> tuple[bool, int]:
        now = time.monotonic()
        start, count = self._hits.get(key, (now, 0))
        if now - start >= self.window_seconds:
            start, count = now, 0
        count += 1
        self._hits[key] = (start, count)
        if len(self._hits) > 5000:
            cutoff = now - self.window_seconds
            self._hits = {k: v for k, v in self._hits.items() if v[0] >= cutoff}
        remaining = max(0, self.limit - count)
        return count <= self.limit, remaining


round_limiter = FixedWindowLimiter(20)
message_limiter = FixedWindowLimiter(40)
check_limiter = FixedWindowLimiter(30)


def _client_key(request: Request) -> str:
    if settings.trust_proxy:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _enforce(request: Request, limiter: FixedWindowLimiter, bucket: str) -> None:
    allowed, remaining = limiter.allow(f"{bucket}:{_client_key(request)}")
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Wait a minute and try again.",
            headers={"Retry-After": "60"},
        )


@router.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "ai": gemini.available,
        "model": settings.gemini_model,
        "scenarios": len(all_scenarios()),
        "version": "0.1.0",
    }


@router.get("/scenarios")
async def scenarios() -> dict:
    return {"scenarios": [scenario.public() for scenario in all_scenarios()]}


@router.post("/rounds", status_code=status.HTTP_201_CREATED)
async def start_round(payload: StartRoundRequest, request: Request) -> dict:
    _enforce(request, round_limiter, "rounds")
    scenario = get_scenario(payload.scenario_id)
    if scenario is None:
        raise HTTPException(status_code=404, detail="Unknown scenario")
    return trainer.start(scenario)


@router.get("/rounds/{round_id}")
async def get_round(round_id: str) -> dict:
    try:
        return trainer.state(round_id)
    except RoundNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Round not found or expired") from exc


@router.post("/rounds/{round_id}/messages")
async def send_message(round_id: str, payload: MessageRequest, request: Request) -> dict:
    _enforce(request, message_limiter, "messages")
    try:
        return await trainer.send(round_id, payload.text)
    except RoundNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Round not found or expired") from exc
    except RoundConflictError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except AIUnavailableError as exc:
        raise HTTPException(
            status_code=503,
            detail="The scammer is offline: Gemini is not configured on this server.",
        ) from exc
    except Exception as exc:  # noqa: BLE001 - never leak provider details
        logger.warning("send_message failed: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="The scammer dropped the call. Try sending that again.",
        ) from exc


@router.post("/rounds/{round_id}/events")
async def record_event(round_id: str, payload: ClientEventRequest, request: Request) -> dict:
    _enforce(request, message_limiter, "events")
    try:
        return await trainer.record_event(round_id, payload.kind, payload.url)
    except RoundNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Round not found or expired") from exc
    except RoundConflictError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/rounds/{round_id}/score")
async def score_round(round_id: str, request: Request) -> dict:
    _enforce(request, message_limiter, "score")
    try:
        return await trainer.score(round_id)
    except RoundNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Round not found or expired") from exc


@router.delete("/rounds/{round_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_round(round_id: str) -> Response:
    try:
        trainer.delete(round_id)
    except RoundNotFoundError:
        pass
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/check/link")
async def check_link(payload: LinkCheckRequest, request: Request) -> dict:
    _enforce(request, check_limiter, "check-link")
    report = analyze_link(payload.url)
    report["ai_explanation"] = await gemini.explain_triage("link", report)
    return report


@router.post("/check/message")
async def check_message(payload: MessageCheckRequest, request: Request) -> dict:
    _enforce(request, check_limiter, "check-message")
    report = analyze_message(payload.text)
    report["ai_explanation"] = await gemini.explain_triage("message", report)
    return report
