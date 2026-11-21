"""Fictional prize / voucher scam."""

from app.scenarios.base import RedFlag, Scenario

SCENARIO = Scenario(
    id="kudu-rewards",
    title="You've won something you never entered",
    org="KuduMart (fictional)",
    channel="SMS",
    difficulty=2,
    teaser="A R5,000 voucher, a midnight deadline and a prize desk that only talks on WhatsApp.",
    brief=(
        "You shop at KuduMart sometimes, but you never entered a birthday draw. An SMS says your "
        "number was selected for a R5,000 voucher. Claiming it takes one WhatsApp message."
    ),
    persona=(
        "You are 'Lerato' from the KuduMart prize desk. You are excited for the winner, "
        "fast-talking and eager to get them onto WhatsApp before the prize desk closes."
    ),
    goal=(
        "Get a R120 'delivery fee' from the customer, then their ID number and home address, "
        "then a card PIN 'to release the voucher'. If they hesitate, say another winner is "
        "waiting."
    ),
    opening=(
        "KUDUMART 30TH BIRTHDAY DRAW: Congratulations! Your number was randomly selected. You "
        "have won a R5,000 KuduMart shopping voucher. To claim, WhatsApp our prize desk on "
        "060 000 0177 and quote WINNER. Claim before midnight or the prize is forfeited."
    ),
    opening_flags=("unexpected_prize", "urgency", "channel_switch", "too_good"),
    red_flags=(
        RedFlag(
            id="unexpected_prize",
            label="A prize you never entered for",
            explanation=(
                "You cannot win a draw you never entered. Real competitions can show you the "
                "entry, the rules and the winner announcement."
            ),
            severity="high",
            spot_patterns=(
                r"(won|winner|prize|selected|competition|draw|lottery)",
                r"(never entered|didn'?t enter|did not enter|never applied)",
            ),
        ),
        RedFlag(
            id="urgency",
            label="Midnight deadline",
            explanation=(
                "A deadline that expires tonight is designed to stop you from checking whether "
                "the competition exists."
            ),
            severity="high",
            spot_patterns=(
                r"(midnight|before|forfeit|expire|tonight|now|claim|deadline)",
            ),
        ),
        RedFlag(
            id="channel_switch",
            label="Moves you to WhatsApp",
            explanation=(
                "The prize desk only exists on WhatsApp, where there is no official record and "
                "the account can vanish."
            ),
            severity="medium",
            spot_patterns=(
                r"(whatsapp|telegram|dm|direct message|chat)",
            ),
        ),
        RedFlag(
            id="personal_details",
            label="Wants ID, address and card details",
            explanation=(
                "A shopping voucher does not need your ID number, home address and card PIN. "
                "Those details are for identity theft, not delivery."
            ),
            severity="high",
            spot_patterns=(
                r"(id( number)?|address|details|card|bank|pin|otp|date of birth)",
            ),
        ),
        RedFlag(
            id="delivery_fee",
            label="Pay a fee to claim the prize",
            explanation=(
                "A legitimate prize never requires a delivery or admin fee before you receive "
                "it. The fee is the actual scam."
            ),
            severity="high",
            spot_patterns=(
                r"(fee|delivery|admin|pay|R\s?120|cost)",
            ),
        ),
        RedFlag(
            id="too_good",
            label="Too good to be true",
            explanation=(
                "A large reward for almost no effort is the oldest hook in the book. If it "
                "sounds too good, it is."
            ),
            severity="medium",
            spot_patterns=(
                r"(R\s?5,?000|voucher|free|too good|no cost|easy money|large prize)",
            ),
        ),
    ),
    fictional_details=(
        "Organisation: KuduMart (fictional retailer)",
        "Prize: R5,000 shopping voucher",
        "Fee: R120 delivery",
        "WhatsApp: 060 000 0177 (placeholder number)",
        "Keyword: WINNER",
        "Agent: Lerato",
    ),
    accent="rose",
)
