# @gloss verifies bill:BillRun
from datetime import date
from decimal import Decimal

from billing.accounts import Account
from billing.run import BillRun


class FakeReadings:
    def between(self, meter_id, start, end):
        return [{"value_kwh": 120.5}, {"value_kwh": 79.5}]


def test_price_multiplies_consumption_by_rate():
    run = BillRun(FakeReadings(), {"E7": Decimal("0.25")})
    account = Account("A-1", "Ada", "E7", ["M-1"])
    assert run.price(account, date(2026, 3, 1), date(2026, 3, 31)) == Decimal("50.00")
