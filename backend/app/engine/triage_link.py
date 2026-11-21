"""Deterministic link triage.

The checker never opens the link. It reads the URL as text and scores the
structural signals that phishing links share: lookalike domains, raw IPs,
punycode, shorteners, suspicious TLDs, credential-harvest paths and so on.

The verdict and score are computed here, in plain Python. Gemini may add a
plain-language explanation afterwards, but it cannot change the verdict.
"""

from __future__ import annotations

import ipaddress
import re
from dataclasses import dataclass
from urllib.parse import urlsplit, urlunsplit

# Registrable domains we know to be official. Used only to spot lookalikes.
BRAND_DOMAINS: dict[str, set[str]] = {
    "capitec": {"capitec.co.za", "capitecbank.co.za"},
    "fnb": {"fnb.co.za"},
    "absa": {"absa.co.za"},
    "standardbank": {"standardbank.co.za"},
    "nedbank": {"nedbank.co.za"},
    "sassa": {"sassa.gov.za"},
    "sars": {"sars.gov.za"},
    "sapo": {"sapo.co.za", "postoffice.co.za"},
    "homeaffairs": {"dha.gov.za"},
    "takealot": {"takealot.com"},
    "discovery": {"discovery.co.za"},
    "vodacom": {"vodacom.co.za"},
    "mtn": {"mtn.co.za"},
    "telkom": {"telkom.co.za"},
    "eskom": {"eskom.co.za"},
    "checkers": {"checkers.co.za"},
    "shoprite": {"shoprite.co.za"},
    "woolworths": {"woolworths.co.za"},
    "bidorbuy": {"bidorbuy.co.za"},
    "paypal": {"paypal.com"},
    "netflix": {"netflix.com"},
    "microsoft": {"microsoft.com", "live.com", "office.com"},
    "apple": {"apple.com", "icloud.com"},
    "google": {"google.com", "gmail.com"},
    "amazon": {"amazon.com", "amazon.co.za"},
    "whatsapp": {"whatsapp.com"},
}

OFFICIAL_DOMAINS: set[str] = {domain for domains in BRAND_DOMAINS.values() for domain in domains}
DOMAIN_TO_BRAND: dict[str, str] = {
    domain: brand for brand, domains in BRAND_DOMAINS.items() for domain in domains
}

MULTI_PART_SUFFIXES = {
    "co.za",
    "org.za",
    "gov.za",
    "ac.za",
    "net.za",
    "web.za",
    "co.uk",
    "org.uk",
    "com.au",
    "co.nz",
    "co.ke",
    "com.br",
}

SHORTENERS = {
    "bit.ly",
    "tinyurl.com",
    "t.co",
    "goo.gl",
    "is.gd",
    "ow.ly",
    "cutt.ly",
    "rb.gy",
    "shorturl.at",
    "buff.ly",
    "rebrand.ly",
    "t.ly",
}

SUSPICIOUS_TLDS = {
    "zip",
    "mov",
    "top",
    "xyz",
    "click",
    "link",
    "live",
    "online",
    "site",
    "icu",
    "cam",
    "rest",
    "buzz",
    "monster",
    "cf",
    "gq",
    "tk",
    "ml",
    "ga",
    "work",
    "support",
}

SUSPICIOUS_PATH = re.compile(
    r"(verify|verification|login|log-in|signin|sign-in|secure|security|account|update|"
    r"otp|pin|grant|refund|payment|pay|invoice|track|tracking|delivery|prize|claim|"
    r"unlock|confirm|recover|reset|billing|wallet|reverse|release)",
    re.IGNORECASE,
)

EXECUTABLE = re.compile(r"\.(apk|exe|scr|msi|bat|cmd|jar|vbs|ps1)(?:$|[?#/])", re.IGNORECASE)


@dataclass(frozen=True)
class Finding:
    id: str
    label: str
    detail: str
    weight: int

    @property
    def severity(self) -> str:
        if self.weight >= 40:
            return "high"
        if self.weight >= 20:
            return "medium"
        return "low"

    def as_dict(self) -> dict:
        return {
            "id": self.id,
            "label": self.label,
            "detail": self.detail,
            "weight": self.weight,
            "severity": self.severity,
        }


def registrable_domain(host: str) -> str:
    labels = [label for label in host.split(".") if label]
    if len(labels) < 2:
        return host
    if len(labels) >= 3 and ".".join(labels[-2:]) in MULTI_PART_SUFFIXES:
        return ".".join(labels[-3:])
    return ".".join(labels[-2:])


def _levenshtein(a: str, b: str) -> int:
    if abs(len(a) - len(b)) > 2:
        return 3
    previous = list(range(len(b) + 1))
    for i, char_a in enumerate(a, start=1):
        current = [i]
        for j, char_b in enumerate(b, start=1):
            current.append(
                min(
                    current[j - 1] + 1,
                    previous[j] + 1,
                    previous[j - 1] + (char_a != char_b),
                )
            )
        previous = current
    return previous[-1]


def _brand_lookalike(host: str, base: str) -> tuple[str, str] | None:
    """Return (brand, reason) when the host imitates a known brand."""
    if base in OFFICIAL_DOMAINS:
        return None
    tokens = re.findall(r"[a-z0-9]+", host)
    for brand in BRAND_DOMAINS:
        if len(brand) < 3:
            continue
        for token in tokens:
            if token == brand:
                return brand, f"uses the name '{brand}' but is not {brand}'s official domain"
            if token.startswith(brand) and len(token) <= len(brand) + 10:
                return brand, f"contains '{brand}' inside a longer word ('{token}')"
            if len(brand) >= 5 and len(token) >= 5 and _levenshtein(token, brand) == 1:
                return brand, f"'{token}' is one letter away from '{brand}'"
    return None


def _verdict(score: int) -> tuple[str, str]:
    if score >= 70:
        return "critical", "Almost certainly a scam link"
    if score >= 40:
        return "high", "Likely phishing"
    if score >= 15:
        return "caution", "Treat with caution"
    return "low", "No structural red flags found"


def _invalid(raw: str, reason: str) -> dict:
    return {
        "input": raw,
        "normalized": raw,
        "host": "",
        "registrable_domain": "",
        "score": 0,
        "verdict": "invalid",
        "verdict_label": reason,
        "severity": "low",
        "is_demo": False,
        "findings": [],
        "advice": ["Paste a full web address, for example https://example.com/page."],
        "not_checked": [],
    }


def analyze_link(raw: str) -> dict:
    """Analyse one URL without any network access."""
    original = (raw or "").strip()
    if not original:
        return _invalid(original, "No link supplied")
    if len(original) > 2048:
        return _invalid(original, "That link is too long to check")

    # Strip punctuation people accidentally copy from a message.
    cleaned = original.strip().strip("<>\"'").rstrip(".,;!?)]}")
    if " " in cleaned or "\n" in cleaned:
        return _invalid(original, "That does not look like a single web address")

    scheme_match = re.match(r"^([a-zA-Z][a-zA-Z0-9+.-]*):", cleaned)
    if scheme_match and scheme_match.group(1).lower() not in {"http", "https"}:
        scheme = scheme_match.group(1).lower()
        finding = Finding(
            id="dangerous_scheme",
            label="Dangerous link type",
            detail=f"This is a '{scheme}:' link, not a normal web page. It can run code or open a local file.",
            weight=100,
        )
        return {
            "input": original,
            "normalized": cleaned,
            "host": "",
            "registrable_domain": "",
            "score": 100,
            "verdict": "critical",
            "verdict_label": "Dangerous link type",
            "severity": "high",
            "is_demo": False,
            "findings": [finding.as_dict()],
            "advice": ["Do not open this link. Delete the message."],
            "not_checked": [],
        }

    had_scheme = bool(scheme_match)
    candidate = cleaned if had_scheme else f"http://{cleaned}"
    try:
        parsed = urlsplit(candidate)
        host = (parsed.hostname or "").strip().lower().rstrip(".")
    except ValueError:
        return _invalid(original, "That does not look like a web address")

    if not host or "." not in host and not _is_ip(host):
        return _invalid(original, "That does not look like a web address")

    findings: list[Finding] = []
    base = registrable_domain(host)

    # Reserved demo domains: ScamGym's own fictional links live here.
    if host == "example.com" or host.endswith(".example.com") or host == "example.test" or host.endswith(".example.test"):
        return {
            "input": original,
            "normalized": urlunsplit(parsed),
            "host": host,
            "registrable_domain": base,
            "score": 0,
            "verdict": "demo",
            "verdict_label": "Reserved practice domain",
            "severity": "low",
            "is_demo": True,
            "findings": [
                Finding(
                    id="reserved_demo",
                    label="Reserved practice domain",
                    detail=(
                        "example.com and example.test are reserved for documentation and demos. "
                        "Nothing on this address is a live organisation."
                    ),
                    weight=0,
                ).as_dict()
            ],
            "advice": [
                "This is a practice link from the simulation. It cannot reach a real company.",
                "In the real world, check the domain letter by letter before you click.",
            ],
            "not_checked": [
                "Whether the site is live",
                "Who registered the domain",
                "What the page would do if opened",
            ],
        }

    if not had_scheme:
        findings.append(
            Finding(
                id="no_scheme",
                label="No https:// prefix",
                detail="We treated this as http://. A real login page should use https://.",
                weight=10,
            )
        )
    elif parsed.scheme.lower() == "http":
        findings.append(
            Finding(
                id="not_https",
                label="Not encrypted (http)",
                detail="Anything typed on an http:// page can be read or changed in transit.",
                weight=15,
            )
        )

    if parsed.username or parsed.password:
        findings.append(
            Finding(
                id="userinfo",
                label="Hidden text before the @",
                detail="The real destination is after the @. Everything before it is decoration.",
                weight=45,
            )
        )

    if _is_ip(host):
        findings.append(
            Finding(
                id="ip_host",
                label="Raw IP address",
                detail="Legitimate banks and couriers use domain names, not a bare IP address.",
                weight=50,
            )
        )

    if "xn--" in host:
        findings.append(
            Finding(
                id="punycode",
                label="Punycode / lookalike alphabet",
                detail="The domain uses encoded characters that can imitate a familiar name.",
                weight=55,
            )
        )

    try:
        host.encode("ascii")
    except UnicodeEncodeError:
        findings.append(
            Finding(
                id="unicode_host",
                label="Non-English characters in the domain",
                detail="Mixed-alphabet domains are a common way to fake a familiar brand.",
                weight=45,
            )
        )

    if base in SHORTENERS:
        findings.append(
            Finding(
                id="shortener",
                label="URL shortener",
                detail="The link hides its real destination behind a shortening service.",
                weight=25,
            )
        )

    tld = host.rsplit(".", 1)[-1]
    if tld in SUSPICIOUS_TLDS:
        findings.append(
            Finding(
                id="suspicious_tld",
                label=f"High-risk domain ending (.{tld})",
                detail="This domain ending is cheap and heavily used for throwaway phishing sites.",
                weight=30,
            )
        )

    lookalike = _brand_lookalike(host, base)
    if lookalike:
        brand, reason = lookalike
        official = ", ".join(sorted(BRAND_DOMAINS[brand]))
        findings.append(
            Finding(
                id="brand_lookalike",
                label="Brand lookalike domain",
                detail=f"The address {reason}. The official domain is {official}.",
                weight=45,
            )
        )
    elif base in OFFICIAL_DOMAINS:
        findings.append(
            Finding(
                id="known_domain",
                label="Known official domain",
                detail=f"{base} matches a known official domain. The page itself can still be compromised or a fake sub-page.",
                weight=0,
            )
        )

    try:
        port = parsed.port
    except ValueError:
        port = -1
    if port not in (None, 80, 443):
        findings.append(
            Finding(
                id="odd_port",
                label="Unusual network port",
                detail=f"The link uses port {port}. Normal websites use 80 or 443.",
                weight=20,
            )
        )

    if len(host) > 45:
        findings.append(
            Finding(
                id="long_host",
                label="Very long domain",
                detail="Long, cluttered domains are used to bury the real destination.",
                weight=10,
            )
        )

    if host.count(".") >= 4:
        findings.append(
            Finding(
                id="many_subdomains",
                label="Many subdomains",
                detail="Extra subdomains are often used to put a trusted name at the front of a hostile address.",
                weight=15,
            )
        )

    if "%" in parsed.netloc:
        findings.append(
            Finding(
                id="encoded_host",
                label="Encoded characters in the address",
                detail="Percent-encoding in the host is a way to hide what the link really points to.",
                weight=25,
            )
        )

    if parsed.path.startswith("//"):
        findings.append(
            Finding(
                id="path_redirect",
                label="Redirect in the path",
                detail="A double slash in the path can send you to a different site.",
                weight=30,
            )
        )

    if SUSPICIOUS_PATH.search(parsed.path) or SUSPICIOUS_PATH.search(parsed.query):
        findings.append(
            Finding(
                id="suspicious_path",
                label="Credential or payment wording in the link",
                detail="The path asks you to verify, pay, claim or unlock something. That is the action the page wants.",
                weight=10,
            )
        )

    if EXECUTABLE.search(parsed.path):
        findings.append(
            Finding(
                id="executable",
                label="Downloadable program",
                detail="The link points to an executable or Android package, not a web page.",
                weight=50,
            )
        )

    if len(original) > 200:
        findings.append(
            Finding(
                id="long_url",
                label="Unusually long link",
                detail="Padding is used to hide the important part of a URL.",
                weight=5,
            )
        )

    # Deduplicate by id, keep the highest weight.
    by_id: dict[str, Finding] = {}
    for finding in findings:
        existing = by_id.get(finding.id)
        if existing is None or finding.weight > existing.weight:
            by_id[finding.id] = finding
    ordered = sorted(by_id.values(), key=lambda item: item.weight, reverse=True)

    score = min(100, sum(finding.weight for finding in ordered))
    verdict, label = _verdict(score)

    advice: list[str] = []
    ids = {finding.id for finding in ordered}
    if "brand_lookalike" in ids:
        advice.append("Check the domain letter by letter against the organisation's official website or app.")
    if "shortener" in ids:
        advice.append("Do not click a shortened link from an unexpected message. Ask for the full address.")
    if "ip_host" in ids:
        advice.append("A real organisation will not send you to a bare IP address.")
    if "punycode" in ids or "unicode_host" in ids:
        advice.append("Do not trust a domain that mixes alphabets. Type the official address yourself.")
    if "not_https" in ids or "no_scheme" in ids:
        advice.append("Never enter a password or card number on a page that is not https://.")
    if "executable" in ids:
        advice.append("Do not download or install the file. Delete the message.")
    if score >= 15:
        advice.append("Open the organisation's official app, or type its address yourself, instead of using this link.")
    advice.append("If you already opened it, close the page, do not enter anything, and change any password you typed.")
    advice.append("A structural check cannot prove a site is safe. It can only show the warning signs.")

    return {
        "input": original,
        "normalized": urlunsplit(parsed),
        "host": host,
        "registrable_domain": base,
        "score": score,
        "verdict": verdict,
        "verdict_label": label,
        "severity": "high" if score >= 40 else ("medium" if score >= 15 else "low"),
        "is_demo": False,
        "findings": [finding.as_dict() for finding in ordered],
        "advice": advice,
        "not_checked": [
            "Whether the site is live",
            "Who registered the domain, or when",
            "Whether the page serves malware",
            "Reputation data (this check is offline)",
            "What is behind a login or download",
        ],
    }


def _is_ip(host: str) -> bool:
    try:
        ipaddress.ip_address(host.strip("[]"))
        return True
    except ValueError:
        return False
