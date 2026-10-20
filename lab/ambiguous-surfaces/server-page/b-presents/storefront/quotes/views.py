from decimal import ROUND_HALF_UP, Decimal

from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, render

from accounts.models import CustomerAccount
from catalog.models import Product

VOLUME_DISCOUNT_MIN_CASES = 50
VOLUME_DISCOUNT_RATE = Decimal("0.08")


# @gloss presents hp:Pricing
@login_required
def quote_view(request, sku):
    """The quote page: what this customer pays for N cases of one product."""
    product = get_object_or_404(Product, sku=sku, active=True)
    account = CustomerAccount.objects.select_related("price_list").get(user=request.user)
    try:
        cases = max(1, int(request.GET.get("cases", "1")))
    except ValueError:
        cases = 1

    unit_cents = product.list_price_cents
    contract = account.price_list.prices.filter(product=product).first() if account.price_list else None
    if contract is not None:
        unit_cents = contract.price_cents

    subtotal = Decimal(unit_cents) * cases
    discount = Decimal(0)
    if cases >= VOLUME_DISCOUNT_MIN_CASES:
        discount = (subtotal * VOLUME_DISCOUNT_RATE).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    total = subtotal - discount

    return render(request, "quotes/quote.html", {
        "product": product,
        "cases": cases,
        "unit_cents": unit_cents,
        "contract_price": contract is not None,
        "subtotal_cents": int(subtotal),
        "discount_cents": int(discount),
        "total_cents": int(total),
        "discount_threshold": VOLUME_DISCOUNT_MIN_CASES,
    })
