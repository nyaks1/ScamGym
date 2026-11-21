"""Output safety filters.

The prompt already forbids real brands, numbers and URLs. This module is the
belt-and-braces layer: if the model slips, the output is repaired before it
ever reaches the learner.
"""

from __future__ import annotations

import re
from urllib.parse import urlsplit

from app.scenarios.base import Scenario

URL_RE = re.compile(r"https?://[^\s<>\"')]+", re.IGNORECASE)
PHONE_RE = re.compile(r"(?<!\d)(?:\+27|0)\s?\d{2}\s?\d{3}\s?\d{4}(?!\d)")

# Real financial / government / retail brands that must never appear in a
# scammer message. Platforms such as WhatsApp are allowed as channel names.
REAL_BRANDS = (
    "capitec",
    "fnb",
    "first national bank",
    "absa",
    "standard bank",
    "nedbank",
    "sassa",
    "sars",
    "sapo",
    "south african post office",
    "takealot",
    "discovery",
    "vodacom",
    "mtn",
    "telkom",
    "eskom",
    "checkers",
    "shoprite",
    "woolworths",
    "paypal",
    "netflix",
    "microsoft",
    "apple",
    "google",
    "amazon",
)

REFUSAL_RE = re.compile(
    r"\b(i can'?t|i cannot|i'?m sorry|i am sorry|as an ai|i'?m unable|i am unable|"
    r"i won'?t (help|roleplay|pretend)|against my (guidelines|policy))\b",
    re.IGNORECASE,
)


def _allowed_link(host: str) -> bool:
    host = host.lower().rstrip(".")
    return host in {"example.com", "example.test"} or host.endswith(".example.com") or host.endswith(".example.test")


def _allowed_numbers(scenario: Scenario) -> set[str]:
    text = " ".join((scenario.opening, *scenario.fictional_details))
    return {re.sub(r"\D", "", match.group(0)) for match in PHONE_RE.finditer(text)}


def sanitize_scammer_text(text: str, scenario: Scenario) -> str:
    """Repair a scammer message that drifted outside the fictional sandbox."""
    cleaned = (text or "").strip()
    if not cleaned:
        return ""

    def replace_url(match: re.Match[str]) -> str:
        url = match.group(0).rstrip(".,;:!?")
        try:
            host = urlsplit(url).hostname or ""
        except ValueError:
            host = ""
        return url if _allowed_link(host) else "[link removed]"

    cleaned = URL_RE.sub(replace_url, cleaned)

    allowed_numbers = _allowed_numbers(scenario)
    fallback_number = next(iter(sorted(allowed_numbers)), "0105550100")
    fallback_pretty = "010 555 0100"
    if len(fallback_number) == 10:
        fallback_pretty = f"{fallback_number[:3]} {fallback_number[3:6]} {fallback_number[6:]}"

    def replace_phone(match: re.Match[str]) -> str:
        digits = re.sub(r"\D", "", match.group(0))
        return match.group(0) if digits in allowed_numbers else fallback_pretty

    cleaned = PHONE_RE.sub(replace_phone, cleaned)

    org_short = scenario.org.split(" (")[0]
    for brand in REAL_BRANDS:
        cleaned = re.sub(rf"\b{re.escape(brand)}\b", org_short, cleaned, flags=re.IGNORECASE)

    # Collapse accidental double spaces introduced by replacements.
    cleaned = re.sub(r"[ \t]{2,}", " ", cleaned).strip()
    return cleaned


def looks_like_refusal(text: str) -> bool:
    return bool(REFUSAL_RE.search(text or ""))
