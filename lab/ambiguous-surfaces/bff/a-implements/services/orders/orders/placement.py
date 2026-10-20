from dataclasses import dataclass


class CreditLimitExceeded(Exception):
    pass


@dataclass(frozen=True)
class Line:
    sku: str
    cases: int
    unit_cents: int


# @gloss implements .CreditCheck
def check_credit(open_balance_cents: int, limit_cents: int, order_cents: int) -> None:
    if open_balance_cents + order_cents > limit_cents:
        raise CreditLimitExceeded(f"order of {order_cents} would exceed limit {limit_cents}")


# @gloss implements .OrderIntake
def place_order(repo, customer_id: str, lines: list[Line]) -> str:
    if not lines or any(line.cases <= 0 for line in lines):
        raise ValueError("an order needs at least one line with a positive case count")
    account = repo.account_for_update(customer_id)
    total = sum(line.cases * line.unit_cents for line in lines)
    check_credit(account.open_balance_cents, account.limit_cents, total)
    return repo.insert_order(customer_id, lines, total)
