import pytest

from orders.placement import CreditLimitExceeded, Line, place_order


# @gloss verifies hp:OrderPlacement
def test_place_order_writes_order(fake_repo):
    fake_repo.add_account("c1", open_balance_cents=0, limit_cents=100_000)
    order_id = place_order(fake_repo, "c1", [Line("OIL-5L", 2, 4200)])
    assert fake_repo.orders[order_id].total_cents == 8400


# @gloss verifies hp:CreditLimit
def test_place_order_refuses_over_limit(fake_repo):
    fake_repo.add_account("c1", open_balance_cents=95_000, limit_cents=100_000)
    with pytest.raises(CreditLimitExceeded):
        place_order(fake_repo, "c1", [Line("OIL-5L", 2, 4200)])
