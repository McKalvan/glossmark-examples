from django.contrib.auth import get_user_model
from django.test import TestCase

from accounts.models import CustomerAccount
from catalog.models import Product


# @gloss verifies hp:Pricing
class QuoteViewTests(TestCase):
    def setUp(self):
        user = get_user_model().objects.create_user("bistro", password="pw")
        CustomerAccount.objects.create(user=user, name="Bistro Nord")
        Product.objects.create(sku="OIL-5L", name="Olive oil 5 L", list_price_cents=4200, active=True)
        self.client.login(username="bistro", password="pw")

    def test_list_price_below_threshold(self):
        resp = self.client.get("/quote/OIL-5L/?cases=10")
        self.assertEqual(resp.context["total_cents"], 42000)
        self.assertEqual(resp.context["discount_cents"], 0)

    def test_volume_discount_at_fifty_cases(self):
        resp = self.client.get("/quote/OIL-5L/?cases=50")
        self.assertEqual(resp.context["subtotal_cents"], 210000)
        self.assertEqual(resp.context["discount_cents"], 16800)
        self.assertEqual(resp.context["total_cents"], 193200)
