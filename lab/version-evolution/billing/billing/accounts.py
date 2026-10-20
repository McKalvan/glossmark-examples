from dataclasses import dataclass, field


# @gloss represents grid:Customer
@dataclass(frozen=True)
class Account:
    account_id: str
    name: str
    tariff_code: str
    meter_ids: list[str] = field(default_factory=list)
