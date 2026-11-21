"""Scenario registry.

Add a scam type by writing a module like the ones in this package and adding
its ``SCENARIO`` here. The engine, prompts and scorer do not change.
"""

from __future__ import annotations

from app.scenarios import kalahari_bank, kudu_rewards, parcelpal, talentbridge, ubuntu_grants
from app.scenarios.base import Scenario, validate_scenario

SCENARIOS: tuple[Scenario, ...] = (
    kalahari_bank.SCENARIO,
    ubuntu_grants.SCENARIO,
    parcelpal.SCENARIO,
    kudu_rewards.SCENARIO,
    talentbridge.SCENARIO,
)

_BY_ID = {scenario.id: scenario for scenario in SCENARIOS}

for _scenario in SCENARIOS:
    validate_scenario(_scenario)


def all_scenarios() -> tuple[Scenario, ...]:
    return SCENARIOS


def get_scenario(scenario_id: str) -> Scenario | None:
    return _BY_ID.get(scenario_id)
