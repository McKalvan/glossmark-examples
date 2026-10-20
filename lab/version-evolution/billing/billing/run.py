from datetime import date
from decimal import Decimal

from billing.accounts import Account


# @gloss implements bill:BillRun
class BillRun:
    def __init__(self, readings, rates):
        self._readings = readings
        self._rates = rates

    def price(self, account: Account, start: date, end: date) -> Decimal:
        kwh = sum(
            Decimal(str(r["value_kwh"]))
            for meter_id in account.meter_ids
            for r in self._readings.between(meter_id, start, end)
        )
        rate = self._rates[account.tariff_code]
        return (kwh * rate).quantize(Decimal("0.01"))
