"""Fictional bank fraud-desk scam.

Inspired by the real-world pattern, but every organisation, person, number and
link here is invented.
"""

from app.scenarios.base import RedFlag, Scenario

SCENARIO = Scenario(
    id="kalahari-bank",
    title="The fraud desk that calls you",
    org="Kalahari Bank (fictional)",
    channel="SMS",
    difficulty=2,
    teaser="A transaction you never made. A helpful agent. A code you should never read out.",
    brief=(
        "You are a Kalahari Bank customer. This SMS arrives on a normal Tuesday morning. "
        "You did not expect a transaction alert, and you have never heard of the merchant."
    ),
    persona=(
        "You are 'Agent Naledi' from the Kalahari Bank Fraud Desk. You are calm, efficient and "
        "slightly impatient. You use the case number, the card ending and bank jargon to sound "
        "official. You want the customer to feel that only you can stop the debit."
    ),
    goal=(
        "Get the customer to read out the one-time PIN sent to their phone, or their card PIN, "
        "so you can 'reverse the transaction'. If they refuse the OTP, ask for the card PIN or "
        "the CVV instead."
    ),
    opening=(
        "KALAHARI BANK FRAUD DESK: A card transaction of R4,850.00 at an unknown merchant was "
        "flagged on account ending 4417. If this was not you, reverse it now: "
        "https://kalahari-bank-secure.example.com/reverse (case KB-8841). Or call 010 555 0142."
    ),
    opening_flags=("urgency", "lookalike_link", "call_me_back"),
    red_flags=(
        RedFlag(
            id="urgency",
            label="Manufactured urgency",
            explanation=(
                "The message pushes you to act immediately, so you do not have time to check "
                "the story through an independent channel."
            ),
            severity="high",
            spot_patterns=(
                r"\b(urgent|urgency|rush|immediately|right now|hurry|deadline|time pressure)\b",
                r"(today|before .*(blocked|closed|too late|lapses)|within \d+ (minutes|hours))",
            ),
        ),
        RedFlag(
            id="lookalike_link",
            label="Lookalike link",
            explanation=(
                "The link uses the bank's name inside a domain that is not the bank's real "
                "domain. Banks do not send customers to a lookalike address to reverse a card."
            ),
            severity="high",
            spot_patterns=(
                r"(link|url|website|domain|address|example\.com|https?://|click(ed|ing)?)",
            ),
        ),
        RedFlag(
            id="call_me_back",
            label="Number supplied by the sender",
            explanation=(
                "The message tells you to call a number it supplied. A real bank expects you to "
                "use the number on the back of your card or in the official app."
            ),
            severity="medium",
            spot_patterns=(
                r"(call(ing)? (you|them|the number|back)|phone number|number in the (sms|message))",
                r"(who am i calling|official number|number on (my|the) card|look(ed|ing)? it up)",
            ),
        ),
        RedFlag(
            id="otp_request",
            label="Asks for an OTP, PIN or CVV",
            explanation=(
                "No real bank will ever ask you to read out a one-time PIN, card PIN or CVV. "
                "That code authorises the transaction; it does not reverse it."
            ),
            severity="high",
            spot_patterns=(
                r"\b(otp|one[- ]time (pin|code)|pin|password|cvv|security code|verification code)\b",
            ),
        ),
        RedFlag(
            id="account_threat",
            label="Threatens your account or money",
            explanation=(
                "Fear of losing money or having an account frozen is used to keep you on the "
                "line. A real fraud team will not pressure you into giving a code."
            ),
            severity="medium",
            spot_patterns=(
                r"(freeze|frozen|block(ed|ing)?|suspend(ed|ing)?|debit order|stolen|lost|drained)",
                r"(close (my|the) account|legal action|money.*(gone|taken))",
            ),
        ),
        RedFlag(
            id="secrecy",
            label="Asks you to keep it secret",
            explanation=(
                "Being told not to discuss the call with family or branch staff isolates you "
                "from the person who would spot the scam."
            ),
            severity="medium",
            spot_patterns=(
                r"(tell (anyone|somebody|someone)|anyone else|between us|secret|confidential)",
                r"(don'?t (tell|discuss)|do not (tell|discuss)|why.*secret)",
            ),
        ),
    ),
    fictional_details=(
        "Organisation: Kalahari Bank (fictional)",
        "Card ending: 4417",
        "Case number: KB-8841",
        "Phone: 010 555 0142 (reserved 555 fictional exchange)",
        "Link host: kalahari-bank-secure.example.com (reserved example domain)",
        "Agent: Naledi",
    ),
    accent="lime",
)
