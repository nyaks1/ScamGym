"""Fictional courier-fee scam."""

from app.scenarios.base import RedFlag, Scenario

SCENARIO = Scenario(
    id="parcelpal",
    title="The parcel that isn't yours",
    org="ParcelPal Couriers (fictional)",
    channel="SMS",
    difficulty=1,
    teaser="A R37 customs fee stands between you and a parcel you never ordered.",
    brief=(
        "You ordered nothing online this month. An SMS says a parcel with your number is stuck "
        "at a depot and will be returned unless a small customs fee is paid."
    ),
    persona=(
        "You are 'Thabo' from ParcelPal customer care. You are helpful but firm about the "
        "deadline. You have a tracking number ready and you are only trying to get the parcel "
        "to the customer before it goes back to the sender."
    ),
    goal=(
        "Get the customer's full card details, including the CVV and expiry date, to pay the "
        "R37 'customs fee'. If they resist, offer to 'hold' the parcel for one more hour."
    ),
    opening=(
        "ParcelPal: Your parcel PP-4471 is on hold at our Cape Town depot. An unpaid customs fee "
        "of R37.00 is required before delivery. Pay here: "
        "https://parcelpal-fees.example.com/pay within 24 hours or the parcel will be returned "
        "to sender."
    ),
    opening_flags=("small_fee", "urgency", "lookalike_link", "unexpected_parcel"),
    red_flags=(
        RedFlag(
            id="small_fee",
            label="A small, unexpected fee",
            explanation=(
                "A fee small enough to feel harmless is used to get card details. The amount is "
                "not the point; the card is."
            ),
            severity="medium",
            spot_patterns=(
                r"(fee|R\s?37|customs|pay(ing|ment)?|charge|small amount)",
            ),
        ),
        RedFlag(
            id="urgency",
            label="Countdown to lose the parcel",
            explanation=(
                "A 24-hour deadline creates panic. Courier companies do not need your card "
                "details by SMS to hold a parcel."
            ),
            severity="high",
            spot_patterns=(
                r"(24 hours|within|returned|return to sender|today|final notice|deadline|before)",
            ),
        ),
        RedFlag(
            id="lookalike_link",
            label="Lookalike link",
            explanation=(
                "The payment link imitates the courier's name but is not the courier's real "
                "domain."
            ),
            severity="high",
            spot_patterns=(
                r"(link|url|website|domain|example\.com|https?://|click(ed|ing)?)",
            ),
        ),
        RedFlag(
            id="unexpected_parcel",
            label="A parcel you never ordered",
            explanation=(
                "If you are not expecting a parcel and the tracking number means nothing to "
                "you, the story is probably invented."
            ),
            severity="medium",
            spot_patterns=(
                r"(parcel|package|tracking|delivery|depot|sender|i (didn'?t|did not) order)",
                r"(not expecting|never ordered|no parcel)",
            ),
        ),
        RedFlag(
            id="card_details",
            label="Wants full card details",
            explanation=(
                "Asking for the card number, expiry and CVV together is how card-not-present "
                "fraud happens. A courier only needs a payment link from your own bank."
            ),
            severity="high",
            spot_patterns=(
                r"(card (number|details)|cvv|expiry|pin|otp|full card)",
            ),
        ),
        RedFlag(
            id="threat",
            label="Threatens to dispose of the parcel",
            explanation=(
                "The threat of return, auction or disposal is there to make you pay before you "
                "think."
            ),
            severity="medium",
            spot_patterns=(
                r"(returned|return to sender|dispose|auction|late fee|forfeit)",
            ),
        ),
    ),
    fictional_details=(
        "Organisation: ParcelPal Couriers (fictional)",
        "Tracking: PP-4471",
        "Fee: R37.00",
        "Depot: Cape Town (fictional)",
        "Link host: parcelpal-fees.example.com (reserved example domain)",
        "Agent: Thabo",
    ),
    accent="sky",
)
