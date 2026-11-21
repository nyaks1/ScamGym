"""Fictional recruitment / training-fee scam."""

from app.scenarios.base import RedFlag, Scenario

SCENARIO = Scenario(
    id="talentbridge",
    title="The job that charges you",
    org="TalentBridge Recruitment (fictional)",
    channel="WhatsApp",
    difficulty=3,
    teaser="A recruiter found your CV. R450 a day, no experience, one small refundable fee.",
    brief=(
        "You have been applying for work. A recruiter messages you on WhatsApp saying she found "
        "your CV online and has a remote data-entry role for you. The pay is good and the start "
        "date is soon."
    ),
    persona=(
        "You are 'Lindiwe' from TalentBridge Recruitment. You are warm, professional and "
        "encouraging. You make the applicant feel chosen. You are efficient because the start "
        "date is close and other candidates are waiting."
    ),
    goal=(
        "Get the R150 'refundable training fee', then the customer's ID number and bank details "
        "for 'payroll'. If they push back, offer to deduct the fee from their first salary."
    ),
    opening=(
        "Hi, this is Lindiwe from TalentBridge Recruitment. We found your CV online. We have a "
        "remote data-entry role at R450 per day, no experience needed. Reply YES on WhatsApp "
        "071 000 0133 to start. A refundable R150 training fee secures your start date."
    ),
    opening_flags=("unsolicited_job", "unrealistic_pay", "channel_switch", "upfront_fee", "pressure"),
    red_flags=(
        RedFlag(
            id="unsolicited_job",
            label="A job you never applied for",
            explanation=(
                "A recruiter who 'found your CV online' and offers a role without an interview "
                "is usually harvesting fees or identity details."
            ),
            severity="high",
            spot_patterns=(
                r"(job|role|recruit|cv|offer|never applied|didn'?t apply|unsolicited|found my)",
            ),
        ),
        RedFlag(
            id="unrealistic_pay",
            label="High pay, no experience",
            explanation=(
                "R450 a day for no-experience data entry is well above the market. The promise "
                "is bait, not a salary."
            ),
            severity="medium",
            spot_patterns=(
                r"(R\s?450|per day|no experience|easy|data entry|too much|high pay)",
            ),
        ),
        RedFlag(
            id="channel_switch",
            label="Recruiting on WhatsApp",
            explanation=(
                "A real employer or agency uses email, a landline and a verifiable address. A "
                "WhatsApp-only recruiter can disappear."
            ),
            severity="medium",
            spot_patterns=(
                r"(whatsapp|telegram|dm|direct message|chat)",
            ),
        ),
        RedFlag(
            id="upfront_fee",
            label="You pay before you earn",
            explanation=(
                "Legitimate employers never charge a training, uniform or placement fee. A "
                "'refundable' fee is still a fee."
            ),
            severity="high",
            spot_patterns=(
                r"(fee|pay|R\s?150|refundable|training|secure.*(start|spot)|deposit)",
            ),
        ),
        RedFlag(
            id="personal_details",
            label="ID and bank details too early",
            explanation=(
                "Payroll details are collected after a signed contract, not before an interview. "
                "Early ID and bank requests are identity-theft signals."
            ),
            severity="high",
            spot_patterns=(
                r"(id( number)?|bank|card|account|pin|otp|details|payroll)",
            ),
        ),
        RedFlag(
            id="pressure",
            label="Start date pressure",
            explanation=(
                "A start date that expires today, with 'limited spots', is a sales tactic. A "
                "real hiring process survives a day of due diligence."
            ),
            severity="medium",
            spot_patterns=(
                r"(start date|today|limited|only \d+ (spots|places)|urgent|reply yes|now)",
            ),
        ),
    ),
    fictional_details=(
        "Organisation: TalentBridge Recruitment (fictional)",
        "Recruiter: Lindiwe",
        "Pay: R450 per day",
        "Fee: R150 refundable training",
        "WhatsApp: 071 000 0133 (placeholder number)",
    ),
    accent="violet",
)
