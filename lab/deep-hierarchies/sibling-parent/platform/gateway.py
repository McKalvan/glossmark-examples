"""Card processor client."""


# @gloss implements spk:PaymentGateway
def charge(token: str, amount_cents: int) -> str:
    if amount_cents <= 0:
        raise ValueError("amount must be positive")
    return f"ch_{token[-6:]}_{amount_cents}"
