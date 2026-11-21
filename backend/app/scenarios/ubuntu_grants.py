"""Fictional government-grant scam."""

from app.scenarios.base import RedFlag, Scenario

SCENARIO = Scenario(
    id="ubuntu-grants",
    title="Free money with a small fee",
    org="Ubuntu Grants Agency (fictional)",
    channel="SMS",
    difficulty=1,
    teaser="Your grant is approved. Just pay a tiny admin fee before 17:00. What could go wrong?",
    brief=(
        "You are between jobs and money is tight. An SMS says a grant you never applied for has "
        "been approved in your name. The payout is real money; the fee is small."
    ),
    persona=(
        "You are 'Sipho' from the Ubuntu Grants Agency call centre. You are friendly, "
        "bureaucratic and full of grant jargon. You are genuinely excited for the beneficiary "
        "and you do not want them to lose their payout because of a tiny admin fee."
    ),
    goal=(
        "Get the R99 admin fee paid, then collect the customer's ID number and bank card details "
        "so the 'grant can be loaded'. If they hesitate, remind them the payout will go to "
        "another applicant."
    ),
    opening=(
        "UBUNTU GRANTS AGENCY: Your application for the R2,200 Special Relief Grant has been "
        "APPROVED. An admin fee of R99 is outstanding. Pay before 17:00 today or your payout "
        "will be released to another applicant: https://ubuntu-grants-pay.example.com/claim "
        "(ref UG-2291). WhatsApp 072 000 0199 for help."
    ),
    opening_flags=("upfront_fee", "urgency", "lookalike_link", "channel_switch", "fake_authority"),
    red_flags=(
        RedFlag(
            id="upfront_fee",
            label="You must pay to receive money",
            explanation=(
                "A genuine grant or payout never requires an upfront 'admin fee'. The fee is the "
                "scam; the R2,200 does not exist."
            ),
            severity="high",
            spot_patterns=(
                r"(fee|pay(ing)?|payment|admin(istration)? (fee|cost)|R\s?99|deposit|outstanding)",
            ),
        ),
        RedFlag(
            id="urgency",
            label="Deadline pressure",
            explanation=(
                "A same-day deadline stops you from checking the agency independently. Real "
                "payments do not disappear because you took an hour to verify."
            ),
            severity="high",
            spot_patterns=(
                r"(today|before \d|17:00|deadline|lapse|expire|another applicant|now|urgent)",
            ),
        ),
        RedFlag(
            id="lookalike_link",
            label="Lookalike link",
            explanation=(
                "The link uses a grant-sounding name on a domain that is not an official "
                "government address."
            ),
            severity="high",
            spot_patterns=(
                r"(link|url|website|domain|example\.com|https?://|click(ed|ing)?)",
            ),
        ),
        RedFlag(
            id="channel_switch",
            label="Moves you to WhatsApp",
            explanation=(
                "Scammers move conversations to WhatsApp or Telegram so the messages are harder "
                "to report and easy to delete."
            ),
            severity="medium",
            spot_patterns=(
                r"(whatsapp|telegram|dm|direct message|chat|move.*(app|platform))",
            ),
        ),
        RedFlag(
            id="personal_details",
            label="Wants ID and banking details",
            explanation=(
                "An ID number plus card details is everything needed to impersonate you or drain "
                "an account. A grant agency does not collect card details over WhatsApp."
            ),
            severity="high",
            spot_patterns=(
                r"(id( number)?|identity|bank(ing)? details|card|account number|pin|otp|cvv)",
            ),
        ),
        RedFlag(
            id="fake_authority",
            label="Official-sounding name and reference",
            explanation=(
                "The agency name and reference number are designed to look official. Anyone can "
                "invent a reference number; it proves nothing."
            ),
            severity="medium",
            spot_patterns=(
                r"(agency|official|reference|ref(erence)?|approved|grant|government)",
            ),
        ),
    ),
    fictional_details=(
        "Organisation: Ubuntu Grants Agency (fictional)",
        "Grant: R2,200 Special Relief Grant",
        "Fee: R99",
        "Reference: UG-2291",
        "WhatsApp: 072 000 0199 (placeholder number)",
        "Link host: ubuntu-grants-pay.example.com (reserved example domain)",
        "Agent: Sipho",
    ),
    accent="amber",
)
