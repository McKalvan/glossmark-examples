from django.db import models


# @gloss represents hp:Order
class Order(models.Model):
    customer_id = models.CharField(max_length=40, db_index=True)
    placed_at = models.DateTimeField(auto_now_add=True)
    total_cents = models.BigIntegerField()
    status = models.CharField(max_length=20, default="placed")


class OrderLine(models.Model):
    order = models.ForeignKey(Order, related_name="lines", on_delete=models.CASCADE)
    sku = models.CharField(max_length=40)
    cases = models.PositiveIntegerField()
    unit_cents = models.BigIntegerField()
