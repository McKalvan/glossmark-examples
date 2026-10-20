import datetime as dt
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction

from billing.models import Invoice, InvoiceLine

SALES_TAX_RATE = Decimal("0.0725")
PAYMENT_TERMS_DAYS = 30


# @gloss implements .InvoiceRun
@transaction.atomic
def invoice_customer(customer_id, deliveries, today=None):
    today = today or dt.date.today()
    subtotal = sum(d.cases * d.unit_cents for d in deliveries)
    taxable = sum(d.cases * d.unit_cents for d in deliveries if d.taxable)
    tax = int((Decimal(taxable) * SALES_TAX_RATE).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    invoice = Invoice.objects.create(
        number=f"HP-{today:%Y%m}-{customer_id}",
        customer_id=customer_id,
        issued_on=today,
        due_on=today + dt.timedelta(days=PAYMENT_TERMS_DAYS),
        subtotal_cents=subtotal,
        tax_cents=tax,
        total_cents=subtotal + tax,
    )
    InvoiceLine.objects.bulk_create(
        InvoiceLine(invoice=invoice, description=d.description, cases=d.cases, unit_cents=d.unit_cents, taxable=d.taxable)
        for d in deliveries
    )
    return invoice
