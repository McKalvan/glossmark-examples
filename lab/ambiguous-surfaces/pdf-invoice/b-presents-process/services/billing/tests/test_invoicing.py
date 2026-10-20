import datetime as dt
from types import SimpleNamespace

import pytest

from billing.invoicing import invoice_customer


# @gloss verifies hp:Invoicing
@pytest.mark.django_db
def test_invoice_totals_with_sales_tax():
    deliveries = [
        SimpleNamespace(description="Olive oil 5 L", cases=10, unit_cents=4200, taxable=False),
        SimpleNamespace(description="Paper napkins", cases=4, unit_cents=1500, taxable=True),
    ]
    inv = invoice_customer("c1", deliveries, today=dt.date(2026, 10, 5))
    assert inv.subtotal_cents == 48000
    assert inv.tax_cents == 435
    assert inv.due_on == dt.date(2026, 11, 4)
