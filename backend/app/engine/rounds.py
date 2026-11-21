"""In-memory round state.

Nothing is written to disk or to a database. A round lives for
``ROUND_TTL_MINUTES`` after its last activity, then it is dropped. The client
holds the visible history; the server holds only what it needs to grade.
"""

from __future__ import annotations

import asyncio
import secrets
import time
from dataclasses import dataclass, field
from typing import Any

from app.engine.scoring import Action
from app.scenarios.base import Scenario


@dataclass
class Round:
    id: str
    scenario: Scenario
    created_at: float
    updated_at: float
    transcript: list[dict[str, str]] = field(default_factory=list)
    planted: set[str] = field(default_factory=set)
    actions: dict[str, Action] = field(default_factory=dict)
    turns: int = 0
    status: str = "active"  # active | ended | scored
    score: dict | None = None
    chat: Any | None = None
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    def public_state(self) -> dict:
        return {
            "round_id": self.id,
            "scenario": self.scenario.public(),
            "transcript": list(self.transcript),
            "turn": self.turns,
            "max_turns": self.scenario.max_turns,
            "status": self.status,
            "score": self.score,
        }


class RoundManager:
    def __init__(self, ttl_minutes: int = 45):
        self._ttl_seconds = max(300, ttl_minutes * 60)
        self._rounds: dict[str, Round] = {}

    def _sweep(self) -> None:
        cutoff = time.time() - self._ttl_seconds
        expired = [round_id for round_id, item in self._rounds.items() if item.updated_at < cutoff]
        for round_id in expired:
            self._rounds.pop(round_id, None)

    def create(self, scenario: Scenario) -> Round:
        self._sweep()
        now = time.time()
        round = Round(
            id=secrets.token_urlsafe(16),
            scenario=scenario,
            created_at=now,
            updated_at=now,
            transcript=[{"role": "scammer", "text": scenario.opening}],
            planted=set(scenario.opening_flags),
        )
        self._rounds[round.id] = round
        return round

    def get(self, round_id: str) -> Round:
        self._sweep()
        round = self._rounds.get(round_id)
        if round is None:
            raise KeyError(round_id)
        return round

    def delete(self, round_id: str) -> bool:
        return self._rounds.pop(round_id, None) is not None

    def count(self) -> int:
        return len(self._rounds)
