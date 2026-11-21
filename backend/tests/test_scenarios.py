"""Every scenario must stay fictional and internally consistent."""

from __future__ import annotations

import re

import pytest

from app.scenarios import all_scenarios, get_scenario

SCENARIOS = all_scenarios()


def test_five_scenarios_are_registered() -> None:
    assert len(SCENARIOS) == 5
    assert len({scenario.id for scenario in SCENARIOS}) == 5


@pytest.mark.parametrize("scenario", SCENARIOS, ids=[s.id for s in SCENARIOS])
def test_public_metadata_hides_the_flags(scenario) -> None:
    public = scenario.public()
    assert "red_flags" not in public
    assert "persona" not in public
    assert public["flag_count"] == len(scenario.red_flags)
    assert 1 <= public["difficulty"] <= 3
    assert public["max_turns"] >= 3


@pytest.mark.parametrize("scenario", SCENARIOS, ids=[s.id for s in SCENARIOS])
def test_every_scenario_uses_reserved_demo_links(scenario) -> None:
    text = "\n".join(
        [scenario.opening, scenario.brief, scenario.goal, scenario.persona, *scenario.fictional_details]
    )
    for url in re.findall(r"https?://[^\s<>\"')]+", text):
        host = url.split("//", 1)[1].split("/", 1)[0]
        assert host == "example.com" or host.endswith(".example.com") or host.endswith(
            ".example.test"
        ), f"{scenario.id} uses a non-reserved link: {url}"


@pytest.mark.parametrize("scenario", SCENARIOS, ids=[s.id for s in SCENARIOS])
def test_every_scenario_uses_fictional_phone_numbers(scenario) -> None:
    text = "\n".join([scenario.opening, *scenario.fictional_details])
    for number in re.findall(r"(?<!\d)(?:0\d{2}\s?\d{3}\s?\d{4})(?!\d)", text):
        digits = re.sub(r"\D", "", number)
        # Fictional numbers use either the reserved 555 exchange or the
        # all-zero placeholder pattern documented in scenarios/base.py.
        assert digits[3:6] in {"555", "000"}, f"{scenario.id} uses a non-fictional number: {number}"


@pytest.mark.parametrize("scenario", SCENARIOS, ids=[s.id for s in SCENARIOS])
def test_opening_flags_exist_and_opening_text_is_present(scenario) -> None:
    assert scenario.opening.strip()
    ids = {flag.id for flag in scenario.red_flags}
    assert set(scenario.opening_flags) <= ids
    assert scenario.opening_flags


def test_unknown_scenario_returns_none() -> None:
    assert get_scenario("does-not-exist") is None
