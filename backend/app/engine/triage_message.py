"""Deterministic message triage.

Paste an SMS, WhatsApp or email. Plain Python matches the language patterns
that scams rely on, extracts any links and runs the link analyser on each one.
The model may explain the result, but it cannot change it.

The message text itself is not sent to Gemini. Only the matched signal labels
and extracted hosts are used for the optional explanation.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from app.engine.triage_link import BRAND_DOMAINS, OFFICIAL_DOMAINS, analyze_link

URL_RE = re.compile(r"(?:https?://|www\.)[^\s<>\"']+", re.IGNORECASE)
BARE_DOMAIN_RE = re.compile(
    r"\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+"
    r"(?:co\.za|org\.za|gov\.za|ac\.za|com|net|org|info|biz|top|xyz|link|click|online|site|live|icu|za)"
    r"(?:/[^\s<>\"']*)?",
    re.IGNORECASE,
)
PHONE_RE = re.compile(r"(?<!\d)(?:\+27|0)\s?\d{2}\s?\d{3}\s?\d{4}(?!\d)")


@dataclass(frozen=True)
class MessageRule:
    id: str
    label: str
    detail: str
    weight: int
    patterns: tuple[str, ...]
    require_all: bool = False
    request_pattern: str | None = None

    def matches(self, text: str) -> bool:
        if self.request_pattern:
            if not any(re.search(pattern, text, re.IGNORECASE) for pattern in self.patterns):
                return False
            return _has_request(text, self.request_pattern)
        checks = [re.search(pattern, text, re.IGNORECASE) is not None for pattern in self.patterns]
        return all(checks) if self.require_all else any(checks)


def _has_request(text: str, request_pattern: str) -> bool:
    for match in re.finditer(request_pattern, text, re.IGNORECASE):
        window = text[max(0, match.start() - 35) : match.start()].lower()
        if re.search(r"(do not|don'?t|never|dont)\s*$", window):
            continue
        return True
    return False


RULES: tuple[MessageRule, ...] = (
    MessageRule(
        id="otp_request",
        label="Asks for a one-time PIN",
        detail="A real bank, courier or agency never asks you to share an OTP. The OTP is the last lock on your money.",
        weight=45,
        patterns=(r"\b(otp|one[- ]time (pin|code)|verification code|security code)\b",),
        request_pattern=r"\b(share|send|give|read|tell|reply with|provide|forward|confirm)\b",
    ),
    MessageRule(
        id="pin_request",
        label="Asks for a card PIN or password",
        detail="No legitimate employee needs your card PIN, password or CVV. Anyone who asks is stealing access, not helping.",
        weight=45,
        patterns=(r"\b(pin|password|passcode|cvv)\b",),
        request_pattern=r"\b(share|send|give|enter|provide|confirm|tell|reply)\b",
    ),
    MessageRule(
        id="card_request",
        label="Asks for card details",
        detail="Full card details let a scammer make payments without ever touching your card.",
        weight=40,
        patterns=(r"(card number|card details|full card|expiry date|card expiry)",),
        request_pattern=r"\b(send|share|provide|enter|confirm|reply|give)\b",
    ),
    MessageRule(
        id="id_request",
        label="Asks for an ID number or document",
        detail="An ID number plus a phone number is enough to start an identity-theft file.",
        weight=30,
        patterns=(r"\b(id number|identity number|id document|passport)\b",),
        request_pattern=r"\b(send|share|provide|reply|confirm|photo|copy|give)\b",
    ),
    MessageRule(
        id="banking_details",
        label="Asks for banking details",
        detail="Banking details are collected through secure, official channels, not by reply message.",
        weight=35,
        patterns=(r"\b(banking details|bank account|account number|branch code)\b",),
        request_pattern=r"\b(send|share|provide|confirm|reply|give)\b",
    ),
    MessageRule(
        id="urgency",
        label="Manufactured urgency",
        detail="A countdown is there to stop you from checking the story through another channel.",
        weight=15,
        patterns=(
            r"\b(act now|immediately|urgent|within \d+ (minutes|hours)|today|before midnight|last chance|final notice|expires?|hurry|deadline|24 hours)\b",
        ),
    ),
    MessageRule(
        id="threat",
        label="Threatens loss or legal action",
        detail="Fear of losing an account, a parcel or money is used to keep you compliant.",
        weight=20,
        patterns=(
            r"(account (will be|has been) (suspended|blocked|frozen|closed)|legal action|arrest|disconnect|deleted|forfeited|returned to sender|penalty|blacklist|debit order)",
        ),
    ),
    MessageRule(
        id="payment",
        label="Asks for a payment",
        detail="Unexpected payment requests should be verified in the organisation's own app, never from the message.",
        weight=15,
        patterns=(r"\b(pay|payment|deposit|transfer|eft|fee|invoice|outstanding|refund)\b",),
    ),
    MessageRule(
        id="prize",
        label="Prize or winner language",
        detail="You cannot win a draw you never entered. Prize language is bait for a fee or personal details.",
        weight=25,
        patterns=(r"\b(congratulations|you(?:'ve| have) won|winner|prize|lottery|selected|reward|voucher|giveaway)\b",),
    ),
    MessageRule(
        id="grant",
        label="Grant or payout language",
        detail="Grant scams promise money and then ask for a fee or banking details. Verify directly with the agency.",
        weight=20,
        patterns=(r"\b(grant|sassa|allowance|relief fund|payout|beneficiary)\b",),
    ),
    MessageRule(
        id="courier",
        label="Parcel or delivery story",
        detail="Courier scams use a small unpaid fee to harvest card details.",
        weight=15,
        patterns=(r"\b(parcel|package|delivery|courier|tracking|depot|customs)\b",),
    ),
    MessageRule(
        id="bank",
        label="Bank or fraud-desk language",
        detail="Banks do not ask for codes or PINs by SMS, WhatsApp or a link.",
        weight=15,
        patterns=(r"\b(bank|fraud desk|transaction|card ending|account ending)\b",),
    ),
    MessageRule(
        id="sars",
        label="Tax refund language",
        detail="Tax refunds are paid into the account SARS already has, not collected through a link.",
        weight=20,
        patterns=(r"\b(sars|tax refund|revenue service|taxpayer)\b",),
    ),
    MessageRule(
        id="job",
        label="Job offer language",
        detail="Legitimate employers do not charge training or placement fees, and they do not hire only over WhatsApp.",
        weight=15,
        patterns=(r"\b(job offer|vacancy|recruit|salary|per day|data entry|work from home|no experience|position)\b",),
    ),
    MessageRule(
        id="investment",
        label="Investment or crypto promise",
        detail="Guaranteed high returns are the signature of a Ponzi or advance-fee scam.",
        weight=20,
        patterns=(r"\b(investment|crypto|bitcoin|forex|double your|guaranteed returns|trading signals)\b",),
    ),
    MessageRule(
        id="romance",
        label="Romance-scam language",
        detail="Fast intimacy from a stranger is a setup for a request for money or details later.",
        weight=15,
        patterns=(r"\b(my love|honey|soulmate|dating|lonely|sweetheart)\b",),
    ),
    MessageRule(
        id="secrecy",
        label="Asks you to keep it secret",
        detail="Secrecy isolates you from the people who would spot the scam.",
        weight=25,
        patterns=(r"(don'?t tell|do not tell|between us|keep (this|it) (quiet|secret)|confidential|don'?t discuss)",),
    ),
    MessageRule(
        id="channel_switch",
        label="Moves you to WhatsApp or Telegram",
        detail="Moving to a chat app makes the conversation harder to report and easy to delete.",
        weight=10,
        patterns=(r"\b(whatsapp|telegram|signal app|dm me|inbox me|chat on)\b",),
    ),
    MessageRule(
        id="remote_access",
        label="Remote access or app install",
        detail="Remote-access tools and sideloaded APKs let a scammer watch you bank or control your phone.",
        weight=40,
        patterns=(
            r"\b(anydesk|teamviewer|quick ?support|screen shar(?:e|ing)|remote access)\b",
            r"(install (this|the) app|download (this|the) app|\.apk\b)",
        ),
    ),
    MessageRule(
        id="credential_harvest",
        label="Wants you to log in or verify",
        detail="A link that asks you to log in is how phishing steals a password. Use the official app instead.",
        weight=30,
        patterns=(
            r"(verify your (account|identity|details)|confirm your (account|identity)|update your (details|banking)|log ?in|sign ?in|password)",
        ),
    ),
    MessageRule(
        id="generic_greeting",
        label="Generic greeting",
        detail="A real organisation usually knows your name. 'Dear customer' is a mass-mail tell.",
        weight=5,
        patterns=(r"\b(dear customer|dear client|dear member|dear user|valued customer|dear sir/madam)\b",),
    ),
    MessageRule(
        id="premium_number",
        label="Premium-rate phone number",
        detail="Premium numbers charge you per minute and are used to drain airtime.",
        weight=20,
        patterns=(r"(?<!\d)(0900\d{6}|0050\d{6})(?!\d)",),
    ),
    MessageRule(
        id="too_good",
        label="Too-good-to-be-true promise",
        detail="Free money, guaranteed returns and risk-free offers are bait.",
        weight=15,
        patterns=(r"\b(free|guaranteed|no risk|risk[- ]free|100%|double your|easy money)\b",),
    ),
    MessageRule(
        id="reply_yes",
        label="Asks you to reply YES",
        detail="A 'reply YES' instruction can subscribe you to a premium service or confirm that your number is live.",
        weight=5,
        patterns=(r"\b(reply (yes|y|1)|sms (yes|y)|send yes)\b",),
    ),
    MessageRule(
        id="sim_swap",
        label="SIM-swap or network story",
        detail="SIM-swap scams convince you to approve a replacement SIM, then intercept your OTPs.",
        weight=25,
        patterns=(r"(sim swap|sim card.*(blocked|replaced|upgrade)|network.*upgrade)",),
    ),
    MessageRule(
        id="fake_reference",
        label="Invented reference number",
        detail="A reference number looks official but proves nothing. Anyone can type one.",
        weight=3,
        patterns=(r"\b(ref(?:erence)?\s*[:#]?\s*[A-Z0-9-]{4,})\b",),
    ),
)


def extract_links(text: str) -> list[str]:
    found: list[str] = []
    for regex in (URL_RE, BARE_DOMAIN_RE):
        for match in regex.finditer(text):
            value = match.group(0).strip().rstrip(".,;!?)]}\"'")
            if value and value not in found:
                found.append(value)
    return found[:5]


def _phone_numbers(text: str) -> list[str]:
    seen: list[str] = []
    for match in PHONE_RE.finditer(text):
        value = match.group(0)
        if value not in seen:
            seen.append(value)
    return seen


def _verdict(score: int) -> tuple[str, str]:
    if score >= 70:
        return "critical", "Almost certainly a scam message"
    if score >= 40:
        return "high", "Likely a scam message"
    if score >= 15:
        return "caution", "Several warning signs"
    return "low", "No common scam signals found"


def _advice_for(ids: set[str], has_link: bool) -> list[str]:
    advice: list[str] = []
    if "otp_request" in ids or "pin_request" in ids:
        advice.append("Never share an OTP, PIN, password or CVV. No real organisation will ask.")
    if has_link:
        advice.append("Do not click the link. Open the organisation's official app or type its address yourself.")
    if "payment" in ids or "banking_details" in ids:
        advice.append("Do not pay or send banking details from this message. Verify the request through an official number you look up yourself.")
    if "prize" in ids or "grant" in ids:
        advice.append("Free money that needs a fee or your details first is a scam. Check the programme directly with the agency.")
    if "courier" in ids:
        advice.append("Track a parcel only on the courier's official website or app, using a tracking number you already have.")
    if "job" in ids:
        advice.append("Never pay for a job. Legitimate employers do not charge training or placement fees.")
    if "remote_access" in ids:
        advice.append("Never install remote-access software or an APK for someone who contacted you.")
    if "urgency" in ids or "threat" in ids:
        advice.append("Slow down. Urgency and threats are the scammer's main tools; a real organisation will still be there tomorrow.")
    if "secrecy" in ids:
        advice.append("Talk to someone you trust. Being told to keep it secret is a red flag.")
    if "investment" in ids:
        advice.append("Check whether the provider is registered with the FSCA before sending any money.")
    if not advice:
        advice.append("Nothing obvious jumped out, but a clean scan is not a guarantee. Verify unexpected requests independently.")
    advice.append("If you already replied, clicked or paid, contact your bank's official fraud line and report the message.")
    return advice


def analyze_message(text: str) -> dict:
    """Analyse one message without any network access."""
    original = (text or "").strip()
    if not original:
        return {
            "input": original,
            "score": 0,
            "verdict": "invalid",
            "verdict_label": "No message supplied",
            "severity": "low",
            "findings": [],
            "links": [],
            "phone_numbers": [],
            "advice": ["Paste the message text you want to check."],
            "not_checked": [],
        }

    findings: list[dict] = []
    for rule in RULES:
        if rule.matches(original):
            findings.append(
                {
                    "id": rule.id,
                    "label": rule.label,
                    "detail": rule.detail,
                    "weight": rule.weight,
                    "severity": "high" if rule.weight >= 40 else ("medium" if rule.weight >= 20 else "low"),
                }
            )

    if len(original) > 30:
        letters = [char for char in original if char.isalpha()]
        if letters and sum(char.isupper() for char in letters) / len(letters) > 0.7:
            findings.append(
                {
                    "id": "all_caps",
                    "label": "Shouting in capitals",
                    "detail": "All-caps urgency is a pressure tactic, not a formal notice.",
                    "weight": 3,
                    "severity": "low",
                }
            )
    if original.count("!") >= 3:
        findings.append(
            {
                "id": "exclamations",
                "label": "Excessive exclamation marks",
                "detail": "Hype punctuation is common in mass scam messages.",
                "weight": 2,
                "severity": "low",
            }
        )

    links = [analyze_link(value) for value in extract_links(original)]
    link_ids = {link["verdict"] for link in links}
    max_link_score = max((link["score"] for link in links if not link["is_demo"]), default=0)
    if max_link_score:
        boost = min(35, max_link_score // 2)
        findings.append(
            {
                "id": "embedded_link",
                "label": "Risky embedded link",
                "detail": f"At least one link in the message scored {max_link_score}/100 in the link checker.",
                "weight": boost,
                "severity": "high" if boost >= 20 else "medium",
            }
        )

    # Brand impersonation: the message names a brand, but the link is not its
    # official domain. This is the strongest single message-level signal.
    mentioned_brands = [
        brand
        for brand in BRAND_DOMAINS
        if re.search(rf"\b{re.escape(brand)}\b", original, re.IGNORECASE)
    ]
    if mentioned_brands:
        brand = mentioned_brands[0]
        official = BRAND_DOMAINS[brand]
        if links and not any(link["is_demo"] for link in links):
            if not any(link["registrable_domain"] in official for link in links):
                findings.append(
                    {
                        "id": "brand_link_mismatch",
                        "label": "Brand name does not match the link",
                        "detail": (
                            f"The message mentions {brand}, but none of its links point to "
                            f"{', '.join(sorted(official))}. That is impersonation."
                        ),
                        "weight": 35,
                        "severity": "high",
                    }
                )
        elif not links and _phone_numbers(original):
            findings.append(
                {
                    "id": "brand_phone",
                    "label": "Brand plus a phone number",
                    "detail": (
                        f"The message uses the name {brand} and a phone number, but nothing here "
                        "proves the sender is that organisation. Look up the number yourself."
                    ),
                    "weight": 15,
                    "severity": "medium",
                }
            )

    # Deduplicate, keep highest weight, then sort.
    by_id: dict[str, dict] = {}
    for finding in findings:
        existing = by_id.get(finding["id"])
        if existing is None or finding["weight"] > existing["weight"]:
            by_id[finding["id"]] = finding
    ordered = sorted(by_id.values(), key=lambda item: item["weight"], reverse=True)

    score = min(100, sum(finding["weight"] for finding in ordered))
    verdict, label = _verdict(score)
    ids = {finding["id"] for finding in ordered}
    has_link = bool(links)

    return {
        "input": original,
        "score": score,
        "verdict": verdict,
        "verdict_label": label,
        "severity": "high" if score >= 40 else ("medium" if score >= 15 else "low"),
        "findings": ordered,
        "links": links,
        "phone_numbers": _phone_numbers(original),
        "advice": _advice_for(ids, has_link),
        "not_checked": [
            "Whether the sender is who they claim to be",
            "Whether the phone number is real or spoofed",
            "What happens if you reply",
            "Reputation data (this check is offline)",
        ],
        "link_verdicts": sorted(link_ids),
        "official_domain_seen": any(link["registrable_domain"] in OFFICIAL_DOMAINS for link in links),
    }
