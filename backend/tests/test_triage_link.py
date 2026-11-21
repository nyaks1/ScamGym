"""Link triage is pure code and must never open the URL."""

from __future__ import annotations

from app.engine.triage_link import analyze_link, registrable_domain


def finding_ids(report: dict) -> set[str]:
    return {finding["id"] for finding in report["findings"]}


def test_reserved_demo_domain_is_marked_as_practice() -> None:
    report = analyze_link("https://kalahari-bank-secure.example.com/reverse")
    assert report["verdict"] == "demo"
    assert report["is_demo"] is True
    assert report["score"] == 0
    assert "reserved_demo" in finding_ids(report)


def test_lookalike_domain_is_high_risk() -> None:
    report = analyze_link("https://paypa1.com/login")
    assert report["verdict"] in {"high", "critical"}
    assert "brand_lookalike" in finding_ids(report)
    assert report["score"] >= 40


def test_raw_ip_address_is_flagged() -> None:
    report = analyze_link("http://197.0.0.1/login")
    assert "ip_host" in finding_ids(report)
    assert "not_https" in finding_ids(report)
    assert report["verdict"] == "critical"


def test_shortener_is_flagged() -> None:
    report = analyze_link("https://bit.ly/3xample")
    assert "shortener" in finding_ids(report)
    assert report["verdict"] == "caution"


def test_suspicious_tld_is_flagged() -> None:
    report = analyze_link("https://kalahari-bank.verify-login.top/reverse")
    assert "suspicious_tld" in finding_ids(report)


def test_punycode_and_hidden_userinfo_are_flagged() -> None:
    assert "punycode" in finding_ids(analyze_link("https://xn--pypal-4ve.com/login"))
    assert "userinfo" in finding_ids(analyze_link("https://capitec.co.za@evil.top/login"))


def test_known_official_domain_has_no_penalty() -> None:
    report = analyze_link("https://capitec.co.za/")
    assert report["verdict"] == "low"
    assert report["score"] == 0
    assert "known_domain" in finding_ids(report)


def test_dangerous_scheme_is_critical() -> None:
    report = analyze_link("javascript:alert(1)")
    assert report["verdict"] == "critical"
    assert report["score"] == 100
    assert "dangerous_scheme" in finding_ids(report)


def test_invalid_input_is_rejected_without_crashing() -> None:
    for raw in ("", "not a url", "http://"):
        report = analyze_link(raw)
        assert report["verdict"] == "invalid"
        assert report["score"] == 0


def test_registrable_domain_handles_za_suffixes() -> None:
    assert registrable_domain("login.capitec.co.za") == "capitec.co.za"
    assert registrable_domain("a.b.example.com") == "example.com"
    assert registrable_domain("localhost") == "localhost"


def test_every_report_says_what_it_cannot_check() -> None:
    report = analyze_link("https://paypa1.com/login")
    assert report["not_checked"]
    assert any("offline" in item.lower() for item in report["not_checked"])
    assert report["advice"]
