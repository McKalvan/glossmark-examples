from django.db import models


# @gloss represents hp:Invoice
class Invoice(models.Model):
    number = models.CharField(max_length=20, unique=True)
    customer_id = models.CharField(max_length=40, db_index=True)
    issued_on = models.DateField()
    due_on = models.DateField()
    subtotal_cents = models.BigIntegerField()
    tax_cents = models.BigIntegerField()
    total_cents = models.BigIntegerField()


class InvoiceLine(models.Model):
    invoice = models.ForeignKey(Invoice, related_name="lines", on_delete=models.CASCADE)
    description = models.CharField(max_length=200)
    cases = models.PositiveIntegerField()
    unit_cents = models.BigIntegerField()
    taxable = models.BooleanField(default=False)
