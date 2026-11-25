"""Deterministic scoring must never depend on the model."""

from __future__ import annotations

import pytest

from app.engine.scoring import (
    Action,
    compute_score,
    detect_actions,
    grade_for,
    otp_was_requested,
)
from app.scenarios import get_scenario


def kinds(text: str, *, otp_requested: bool = False) -> set[str]:
    return {action.kind for action in detect_actions(text, otp_requested=otp_requested)}


# ---- action detection ---------------------------------------------------


def test_shared_otp_needs_an_otp_context() -> None:
    assert "shared_otp" not in kinds("My reference is 4417")
    assert "shared_otp" in kinds("The code is 4417", otp_requested=True)


def test_refusing_to_share_an_otp_is_not_sharing_it() -> None:
    assert "shared_otp" not in kinds("I will not share the OTP 4417", otp_requested=True)


def test_pin_and_password_are_detected() -> None:
    assert "shared_pin" in kinds("My PIN is 4417")
    assert "shared_pin" in kinds("password: 8842")


def test_card_number_is_redacted_and_detected() -> None:
    actions = detect_actions("Card 4111 1111 1111 1111 exp 09/28")
    card = next(action for action in actions if action.kind == "shared_card")
    assert card.evidence == "[redacted card number]"


def test_sa_id_number_is_detected_separately_from_a_card() -> None:
    found = kinds("My ID number is 9001015009087")
    assert "shared_id" in found
    assert "shared_card" not in found


def test_money_and_remote_access_are_detected() -> None:
    found = kinds("I already paid, and I installed AnyDesk like you said")
    assert "sent_money" in found
    assert "installed_app" in found
    assert "remote_access" in found


def test_good_moves_are_detected() -> None:
    found = kinds("I will call the bank on the official number on my card. This is a scam.")
    assert "verified_independently" in found
    assert "refused" in found


def test_verification_question_is_detected() -> None:
    assert "asked_verification" in kinds("Who are you and what is the case number?")


def test_otp_was_requested_scans_scammer_lines_only() -> None:
    assert otp_was_requested(["Please send me the OTP"])
    assert not otp_was_requested(["Hello, how are you?"])


# ---- scoring ------------------------------------------------------------


def test_grade_boundaries() -> None:
    assert grade_for(100)[0] == "A+"
    assert grade_for(90)[0] == "A"
    assert grade_for(80)[0] == "B"
    assert grade_for(70)[0] == "C"
    assert grade_for(60)[0] == "D"
    assert grade_for(50)[0] == "E"
    assert grade_for(0)[0] == "F"


def test_score_is_deterministic_and_clamped() -> None:
    scenario = get_scenario("kalahari-bank")
    assert scenario is not None

    kwargs = dict(
        planted_flag_ids=scenario.opening_flags,
        user_messages=["I will call the bank myself."],
        actions=[Action(kind="verified_independently", source="code")],
        turn_count=2,
    )
    first = compute_score(scenario, **kwargs)
    second = compute_score(scenario, **kwargs)
    assert first == second
    assert 0 <= first["score"] <= 100


def test_clicking_and_sharing_otp_costs_more_than_refusing() -> None:
    scenario = get_scenario("kalahari-bank")
    assert scenario is not None
    flags = scenario.opening_flags

    bad = compute_score(
        scenario,
        planted_flag_ids=flags,
        user_messages=["Here is the OTP 4417. I clicked the link."],
        actions=[
            Action(kind="shared_otp", source="code"),
            Action(kind="clicked_link", source="client"),
        ],
        turn_count=3,
    )
    good = compute_score(
        scenario,
        planted_flag_ids=flags,
        user_messages=["I will not share anything. This is a scam."],
        actions=[Action(kind="refused", source="code")],
        turn_count=3,
    )

    assert bad["score"] < good["score"]
    assert bad["breakdown"]["action_penalty"] < 0
    assert good["breakdown"]["action_bonus"] > 0

    bad_points = {action["kind"]: action["points"] for action in bad["actions"]}
    assert bad_points["shared_otp"] < 0
    assert bad_points["clicked_link"] < 0

    good_points = {action["kind"]: action["points"] for action in good["actions"]}
    assert good_points["refused"] > 0


def test_spotted_flags_are_matched_from_the_learners_own_words() -> None:
    scenario = get_scenario("kalahari-bank")
    assert scenario is not None

    result = compute_score(
        scenario,
        planted_flag_ids={"lookalike_link"},
        user_messages=["I am not clicking that link. It is not the bank's domain."],
        actions=[],
        turn_count=1,
    )

    planted = result["flags"]["planted"]
    assert planted and planted[0]["id"] == "lookalike_link"
    assert planted[0]["spotted"] is True
    assert result["breakdown"]["flag_bonus"] > 0


def test_unplanted_flags_are_not_scored() -> None:
    scenario = get_scenario("talentbridge")
    assert scenario is not None
    result = compute_score(
        scenario,
        planted_flag_ids=set(),
        user_messages=["No thanks."],
        actions=[Action(kind="refused", source="code")],
        turn_count=1,
    )
    assert result["flags"]["planted"] == []
    assert result["breakdown"]["flag_penalty"] == 0


@pytest.mark.parametrize("scenario_id", ["kalahari-bank", "ubuntu-grants", "parcelpal", "kudu-rewards", "talentbridge"])
def test_every_scenario_can_be_scored(scenario_id: str) -> None:
    scenario = get_scenario(scenario_id)
    assert scenario is not None
    result = compute_score(
        scenario,
        planted_flag_ids=scenario.opening_flags,
        user_messages=["Who is this?"],
        actions=[],
        turn_count=1,
    )
    assert set(result) >= {"score", "grade", "verdict", "flags", "actions", "breakdown", "advice"}
