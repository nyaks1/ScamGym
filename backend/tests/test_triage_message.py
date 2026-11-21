"""Message triage is pure code; links inside messages reuse the link checker."""

from __future__ import annotations

from app.engine.triage_message import analyze_message, extract_links


def ids(report: dict) -> set[str]:
    return {finding["id"] for finding in report["findings"]}


def test_otp_request_is_high_risk() -> None:
    report = analyze_message(
        "KALAHARI BANK: Suspicious login on account ending 4417. "
        "Reply with the OTP we just sent to cancel the transfer. Do not tell anyone."
    )
    assert "otp_request" in ids(report)
    assert "credential_harvest" in ids(report)
    assert report["verdict"] == "critical"


def test_negated_otp_warning_is_not_a_request() -> None:
    report = analyze_message("Never share your OTP with anyone, not even if they claim to be your bank.")
    assert "otp_request" not in ids(report)
    assert report["verdict"] in {"low", "caution"}


def test_benign_personal_message_is_low_risk() -> None:
    report = analyze_message("Hi Mom, I will be home around 6. Please buy bread on the way. Love you.")
    assert report["score"] == 0
    assert report["verdict"] == "low"
    assert report["findings"] == []


def test_grant_fee_scam_is_flagged() -> None:
    report = analyze_message(
        "UBUNTU GRANTS: Your R2,200 grant is approved. Pay the R99 admin fee today at "
        "https://ubuntu-grants-pay.example.com/claim or lose the payout. WhatsApp 072 000 0199."
    )
    found = ids(report)
    assert {"grant", "payment", "urgency"}.issubset(found)
    assert report["verdict"] in {"high", "critical"}
    assert report["phone_numbers"] == ["072 000 0199"]


def test_risky_embedded_link_raises_the_score() -> None:
    report = analyze_message("Verify your account now: https://paypa1.com/login")
    assert "embedded_link" in ids(report)
    assert report["links"]
    assert report["links"][0]["verdict"] in {"high", "critical"}
    assert report["verdict"] in {"high", "critical"}


def test_demo_link_is_not_treated_as_a_risky_link() -> None:
    report = analyze_message("Parcel held. Pay here: https://parcelpal-fees.example.com/pay")
    assert "embedded_link" not in ids(report)
    assert report["links"][0]["is_demo"] is True


def test_brand_name_must_match_the_link() -> None:
    report = analyze_message("Capitec: verify your account at https://capitec-secure.top/login")
    assert "brand_link_mismatch" in ids(report)
    assert report["verdict"] == "critical"


def test_remote_access_and_secrecy_are_flagged() -> None:
    report = analyze_message(
        "Install AnyDesk so I can help you. Do not tell your family about this call."
    )
    found = ids(report)
    assert "remote_access" in found
    assert "secrecy" in found


def test_extract_links_finds_bare_domains_and_deduplicates() -> None:
    links = extract_links("Go to www.capitec.co.za or https://capitec.co.za, then www.capitec.co.za")
    assert links
    assert len(links) == len(set(links))
    assert any("capitec.co.za" in link for link in links)


def test_empty_message_is_invalid() -> None:
    report = analyze_message("   ")
    assert report["verdict"] == "invalid"
    assert report["score"] == 0
