"""Checkout handler."""


# @gloss implements spk:CheckoutFlow
def checkout(basket_total_cents: int, token: str, charge) -> str:
    return charge(token, basket_total_cents)
