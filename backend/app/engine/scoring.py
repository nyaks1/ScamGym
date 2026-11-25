"""Deterministic scoring.

The model writes the scam and can ask for a score, but it never decides the
score. Everything below is plain Python and is unit-tested.

Two inputs feed the score:

* which red flags were planted (the scenario's opening flags, plus any the
  model declared through ``plant_red_flag``);
* what the learner did (detected here from their own words, plus link clicks
  recorded by the client, plus model hints that are re-validated here).

Sensitive values (OTPs, card numbers, ID numbers) are never stored: evidence
is redacted before it reaches the round state or any response.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

from app.scenarios.base import Scenario

ACTION_LABELS: dict[str, str] = {
    "shared_otp": "Shared a one-time PIN",
    "shared_pin": "Shared a card PIN or password",
    "shared_card": "Shared card details",
    "shared_id": "Shared an ID number",
    "shared_personal_info": "Shared personal details",
    "clicked_link": "Clicked a link",
    "sent_money": "Sent money",
    "installed_app": "Installed an app on request",
    "remote_access": "Gave remote access",
    "contacted_scammer": "Called the number in the message",
    "kept_secret": "Agreed to keep it secret",
    "verified_independently": "Verified through an independent channel",
    "refused": "Refused the request",
    "asked_verification": "Asked a verification question",
    "reported": "Reported or blocked the sender",
}

PENALTIES: dict[str, int] = {
    "shared_otp": 35,
    "shared_pin": 40,
    "shared_card": 40,
    "shared_id": 20,
    "shared_personal_info": 15,
    "clicked_link": 20,
    "sent_money": 30,
    "installed_app": 25,
    "remote_access": 40,
    "contacted_scammer": 10,
    "kept_secret": 10,
}

BONUSES: dict[str, int] = {
    "verified_independently": 10,
    "refused": 8,
    "asked_verification": 4,
    "reported": 6,
}

ACTION_ADVICE: dict[str, str] = {
    "shared_otp": "Never read out an OTP. That code approves the transaction; it cannot reverse one.",
    "shared_pin": "Never share a card PIN or password. No bank employee needs it, ever.",
    "shared_card": "Never send full card details over SMS or WhatsApp. Use the bank's own app or a virtual card.",
    "shared_id": "An ID number is enough to start an identity-theft file. Share it only through a verified, official channel.",
    "shared_personal_info": "Personal details are currency to a scammer. Give the minimum, and only after you have verified who you are talking to.",
    "clicked_link": "Do not click links in unexpected messages. Open the organisation's app or type its official address yourself.",
    "sent_money": "If money has left your account, call your bank's official fraud line immediately and open a case.",
    "installed_app": "Never install an app because someone in a message asked you to. Sideloaded APKs are a common banking-trojan route.",
    "remote_access": "Never give a stranger remote access to your phone or computer. They can watch you bank.",
    "contacted_scammer": "Look up the organisation's number yourself. The number in the message belongs to the scammer.",
    "kept_secret": "Secrecy isolates you. Tell someone you trust and check the story with them.",
    "verified_independently": "Good move. Independent verification is the single strongest defence.",
    "refused": "Good refusal. You do not owe a stranger your details or your money.",
    "asked_verification": "Good question. Keep asking until the answer can be checked independently.",
    "reported": "Reporting helps the next person and makes the scam less profitable.",
}

SEVERITY_PENALTY: dict[str, int] = {"low": 4, "medium": 6, "high": 8}
SPOT_BONUS = 5
SPOT_BONUS_CAP = 20
BONUS_CAP = 18


@dataclass(frozen=True)
class Action:
    kind: str
    source: str  # "code" | "client" | "model"
    evidence: str = ""


_CODE_RE = re.compile(r"(?<!\d)(\d{4,8})(?!\d)")
_NEGATED_RE = re.compile(
    r"(won'?t|will not|not|never|can'?t|cannot|don'?t|do not)\s+"
    r"(share|send|give|read|tell|provide|enter|pay)",
    re.IGNORECASE,
)
_PIN_RE = re.compile(
    r"(?:\b(?:pin|password|passcode)\b[^.\n]{0,25}?(?<!\d)\d{4,6}(?!\d))"
    r"|(?:(?<!\d)\d{4,6}(?!\d)[^.\n]{0,15}?\b(?:pin|password|passcode)\b)",
    re.IGNORECASE,
)
_CARD_RE = re.compile(r"(?<!\d)(?:\d[ -]?){15,19}(?!\d)")
_ID_RE = re.compile(r"(?<!\d)\d{13}(?!\d)")
_PERSONAL_RE = re.compile(
    r"\b(?:my|our)\s+(?:home\s+)?(?:address|date of birth|dob|surname|full name|id number)\s*(?:is|:)\s*\S+",
    re.IGNORECASE,
)
_MONEY_RE = re.compile(
    r"\b(?:i|we)\s+(?:have\s+|just\s+|already\s+)?(?:paid|sent|transferred|deposited|eft)\b"
    r"|\bpayment\s+(?:is\s+)?(?:done|made|sent)\b"
    r"|\bproof of payment\b",
    re.IGNORECASE,
)
_APP_RE = re.compile(
    r"\b(?:installed|downloaded|install|download)\b[^.\n]{0,30}\b(?:app|apk|anydesk|teamviewer)\b",
    re.IGNORECASE,
)
_REMOTE_RE = re.compile(
    r"\b(anydesk|teamviewer|quick\s?support|screen\s?shar(?:e|ing)|remote access)\b",
    re.IGNORECASE,
)
_CONTACTED_RE = re.compile(
    r"\b(?:i|we)\s+(?:called|phoned|rang|dialled|dialed)\b[^.\n]{0,40}(?:\d|number)",
    re.IGNORECASE,
)
_SECRET_RE = re.compile(
    r"(?:won'?t|will not|not going to)\s+tell"
    r"|\bbetween us\b|\bour secret\b|\bkeep (?:this|it) (?:quiet|secret)\b",
    re.IGNORECASE,
)
_VERIFIED_RE = re.compile(
    r"(?:i'?ll|i will|let me|going to|i'?m going to)\s+"
    r"(?:call|phone|check|verify|visit|go to)\b[^.\n]{0,40}"
    r"(?:bank|branch|app|website|official|them|number)"
    r"|\bofficial (?:number|website|app|branch)\b"
    r"|\bnumber on (?:the|my) card\b",
    re.IGNORECASE,
)
_REFUSED_RE = re.compile(
    r"(?:i'?m not|i am not|i won'?t|i will not|not going to|refuse to|no thanks|not sharing|not sending)"
    r"|\bstop (?:messaging|contacting|texting|calling)\b"
    r"|\bthis is a scam\b|\byou'?re a scam\b|\byou are a scam\b"
    r"|\bleave me alone\b|\bi don'?t trust\b",
    re.IGNORECASE,
)
_ASKED_RE = re.compile(
    r"(?:who|which|how do i know|prove|verify|why do you need|what bank|official|real|case number|reference)",
    re.IGNORECASE,
)
_REPORTED_RE = re.compile(r"\b(report(?:ed|ing)?|block(?:ed|ing)?|screenshot)\b", re.IGNORECASE)


def _search(pattern: re.Pattern[str], text: str) -> str | None:
    match = pattern.search(text)
    return match.group(0) if match else None


def _negated(text: str, start: int) -> bool:
    window = text[max(0, start - 45) : start]
    return _NEGATED_RE.search(window) is not None


def detect_actions(text: str, *, otp_requested: bool = False) -> list[Action]:
    """Detect risky or wise actions in one learner message.

    Detection is deliberately conservative: a refusal ("I won't share the OTP")
    is not recorded as sharing, and only 15-19 digit card-like numbers count as
    card details (a 13-digit SA ID number is scored separately).
    """
    text = text or ""
    found: dict[str, Action] = {}

    def add(kind: str, evidence: str) -> None:
        found.setdefault(kind, Action(kind=kind, source="code", evidence=evidence))

    otp_context = otp_requested or re.search(
        r"\b(otp|one[- ]time (pin|code)|verification code)\b", text, re.IGNORECASE
    )
    for match in _CODE_RE.finditer(text):
        if _negated(text, match.start()):
            continue
        if otp_context:
            add("shared_otp", "[redacted code]")
            break

    pin_match = _PIN_RE.search(text)
    if pin_match and not _negated(text, pin_match.start()):
        add("shared_pin", "[redacted PIN]")

    card_match = _CARD_RE.search(text)
    if card_match:
        digits = re.sub(r"\D", "", card_match.group(0))
        if 15 <= len(digits) <= 19 and not _ID_RE.fullmatch(digits):
            add("shared_card", "[redacted card number]")

    if _ID_RE.search(text):
        add("shared_id", "[redacted ID number]")

    personal_match = _PERSONAL_RE.search(text)
    if personal_match:
        add("shared_personal_info", "[redacted personal detail]")

    money_match = _MONEY_RE.search(text)
    if money_match and not _negated(text, money_match.start()):
        add("sent_money", money_match.group(0).strip())

    app_match = _APP_RE.search(text)
    if app_match and not _negated(text, app_match.start()):
        add("installed_app", app_match.group(0).strip())

    remote_match = _REMOTE_RE.search(text)
    if remote_match and not _negated(text, remote_match.start()):
        add("remote_access", remote_match.group(0).strip())

    contacted_match = _CONTACTED_RE.search(text)
    if contacted_match:
        add("contacted_scammer", contacted_match.group(0).strip())

    secret_match = _SECRET_RE.search(text)
    if secret_match:
        add("kept_secret", secret_match.group(0).strip())

    verified_match = _VERIFIED_RE.search(text)
    if verified_match:
        add("verified_independently", verified_match.group(0).strip())

    refused_match = _REFUSED_RE.search(text)
    if refused_match:
        add("refused", refused_match.group(0).strip())

    if "?" in text and _ASKED_RE.search(text):
        add("asked_verification", "asked a verification question")

    reported_match = _REPORTED_RE.search(text)
    if reported_match:
        add("reported", reported_match.group(0).strip())

    return list(found.values())


def action_supported(kind: str, text: str, *, otp_requested: bool = False) -> bool:
    """Used to validate a model's ``record_user_action`` hint.

    The model may notice something the regexes missed, but it cannot invent a
    penalty: the action must be visible in the learner's own message.
    """
    return any(action.kind == kind for action in detect_actions(text, otp_requested=otp_requested))


def otp_was_requested(scammer_messages: Iterable[str]) -> bool:
    pattern = re.compile(
        r"\b(otp|one[- ]time (pin|code)|pin|password|cvv|verification code|security code)\b",
        re.IGNORECASE,
    )
    return any(pattern.search(message or "") for message in scammer_messages)


def _flag_dict(flag, *, spotted: bool) -> dict:
    return {
        "id": flag.id,
        "label": flag.label,
        "explanation": flag.explanation,
        "severity": flag.severity,
        "spotted": spotted,
    }


def grade_for(score: int) -> tuple[str, str]:
    if score >= 95:
        return "A+", "Scam-proof. You kept the upper hand from the first message."
    if score >= 90:
        return "A", "Scam-proof. Nothing important slipped past you."
    if score >= 80:
        return "B", "Sharp. One or two tells got past you, but you held the line."
    if score >= 70:
        return "C", "Getting there. The scammer found some traction."
    if score >= 60:
        return "D", "Shaken. You gave away more than you should have."
    if score >= 50:
        return "E", "Badly rattled. This one nearly had you."
    return "F", "You got hooked. Run it again - that is what the gym is for."


def compute_score(
    scenario: Scenario,
    *,
    planted_flag_ids: Iterable[str],
    user_messages: Iterable[str],
    actions: Iterable[Action],
    turn_count: int,
) -> dict:
    """Return the full, deterministic weigh-in."""
    planted_ids = set(planted_flag_ids)
    planted = [flag for flag in scenario.red_flags if flag.id in planted_ids]
    user_text = "\n".join(message for message in user_messages if message)[-8000:]

    spotted = [
        flag
        for flag in planted
        if any(re.search(pattern, user_text, re.IGNORECASE) for pattern in flag.spot_patterns)
    ]
    spotted_ids = {flag.id for flag in spotted}
    missed = [flag for flag in planted if flag.id not in spotted_ids]

    unique_actions: dict[str, Action] = {}
    for action in actions:
        unique_actions.setdefault(action.kind, action)

    penalties = [
        {"kind": kind, "label": ACTION_LABELS.get(kind, kind), "points": -PENALTIES[kind]}
        for kind in unique_actions
        if kind in PENALTIES
    ]
    bonuses = [
        {"kind": kind, "label": ACTION_LABELS.get(kind, kind), "points": BONUSES[kind]}
        for kind in unique_actions
        if kind in BONUSES
    ]

    flag_bonus = min(SPOT_BONUS_CAP, SPOT_BONUS * len(spotted))
    flag_penalty = sum(SEVERITY_PENALTY[flag.severity] for flag in missed)
    action_penalty = sum(PENALTIES[action.kind] for action in unique_actions.values() if action.kind in PENALTIES)
    action_bonus = min(BONUS_CAP, sum(BONUSES[action.kind] for action in unique_actions.values() if action.kind in BONUSES))

    raw = 100 + flag_bonus - flag_penalty - action_penalty + action_bonus
    score = max(0, min(100, raw))
    grade, verdict = grade_for(score)

    advice: list[str] = []
    for kind in unique_actions:
        if kind in ACTION_ADVICE and kind not in BONUSES:
            advice.append(ACTION_ADVICE[kind])
    for flag in missed:
        advice.append(f"Missed tell - {flag.label}: {flag.explanation}")
    if not advice:
        advice.append("Nothing to fix this round. Try a harder scenario or a different scam type.")
    if len(advice) > 8:
        advice = advice[:8]

    return {
        "score": score,
        "grade": grade,
        "verdict": verdict,
        "summary": (
            f"{len(spotted)} of {len(planted)} planted red flags spotted. "
            f"{len(penalties)} risky action{'s' if len(penalties) != 1 else ''}, "
            f"{len(bonuses)} good move{'s' if len(bonuses) != 1 else ''}."
        ),
        "flags": {
            "planted": [_flag_dict(flag, spotted=flag.id in spotted_ids) for flag in planted],
            "spotted": [_flag_dict(flag, spotted=True) for flag in spotted],
            "missed": [_flag_dict(flag, spotted=False) for flag in missed],
        },
        "actions": [
            {
                "kind": action.kind,
                "label": ACTION_LABELS.get(action.kind, action.kind),
                "points": -PENALTIES[action.kind]
                if action.kind in PENALTIES
                else BONUSES.get(action.kind, 0),
                "source": action.source,
            }
            for action in unique_actions.values()
        ],
        "penalties": penalties,
        "bonuses": bonuses,
        "breakdown": {
            "start": 100,
            "flag_bonus": flag_bonus,
            "flag_penalty": -flag_penalty,
            "action_penalty": -action_penalty,
            "action_bonus": action_bonus,
        },
        "advice": advice,
        "turn_count": turn_count,
    }
