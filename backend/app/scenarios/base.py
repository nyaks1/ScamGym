"""Scenario module format.

A scenario is a self-contained Python module: persona, planted red flags,
fictional details and failure conditions. Adding a scam type means adding a
module and registering it in ``app.scenarios`` - never rewriting the engine.

Everything in a scenario must be fictional. Links use the reserved
``example.com`` / ``example.test`` domains. Phone numbers use the reserved
``555`` exchange or the all-zero placeholder pattern.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

SEVERITIES = {"low": 4, "medium": 6, "high": 8}


@dataclass(frozen=True)
class RedFlag:
    """One teachable tell that the scammer is instructed to plant."""

    id: str
    label: str
    explanation: str
    severity: str
    # Regexes that detect the learner calling this flag out in their own words.
    spot_patterns: tuple[str, ...]

    def __post_init__(self) -> None:
        if self.severity not in SEVERITIES:
            raise ValueError(f"{self.id}: severity must be one of {sorted(SEVERITIES)}")
        if not self.spot_patterns:
            raise ValueError(f"{self.id}: needs at least one spot pattern")
        for pattern in self.spot_patterns:
            re.compile(pattern, re.IGNORECASE)


@dataclass(frozen=True)
class Scenario:
    id: str
    title: str
    org: str
    channel: str
    difficulty: int
    teaser: str
    brief: str
    persona: str
    goal: str
    opening: str
    opening_flags: tuple[str, ...]
    red_flags: tuple[RedFlag, ...]
    fictional_details: tuple[str, ...]
    max_turns: int = 8
    accent: str = "lime"

    def flag(self, flag_id: str) -> RedFlag | None:
        return next((flag for flag in self.red_flags if flag.id == flag_id), None)

    def public(self) -> dict[str, Any]:
        """Metadata safe to show before a round. Flag labels stay hidden."""
        return {
            "id": self.id,
            "title": self.title,
            "org": self.org,
            "channel": self.channel,
            "difficulty": self.difficulty,
            "teaser": self.teaser,
            "brief": self.brief,
            "max_turns": self.max_turns,
            "flag_count": len(self.red_flags),
            "accent": self.accent,
        }


def validate_scenario(scenario: Scenario) -> None:
    if not scenario.id or not re.fullmatch(r"[a-z0-9-]+", scenario.id):
        raise ValueError(f"invalid scenario id: {scenario.id!r}")
    if scenario.difficulty not in {1, 2, 3}:
        raise ValueError(f"{scenario.id}: difficulty must be 1-3")
    if scenario.max_turns < 3:
        raise ValueError(f"{scenario.id}: max_turns must be >= 3")
    ids = [flag.id for flag in scenario.red_flags]
    if len(ids) != len(set(ids)):
        raise ValueError(f"{scenario.id}: duplicate red flag ids")
    if not scenario.opening_flags:
        raise ValueError(f"{scenario.id}: needs at least one opening flag")
    for flag_id in scenario.opening_flags:
        if flag_id not in ids:
            raise ValueError(f"{scenario.id}: unknown opening flag {flag_id!r}")
    if not scenario.opening.strip():
        raise ValueError(f"{scenario.id}: opening message is empty")
