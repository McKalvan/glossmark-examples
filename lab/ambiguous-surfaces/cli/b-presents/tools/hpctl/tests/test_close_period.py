import datetime as dt

from click.testing import CliRunner

from hpctl.cli import main


# @gloss verifies hp:PeriodClose
def test_close_period_posts_accruals_and_locks(finance_db):
    finance_db.seed_period(dt.date(2026, 9, 1))
    finance_db.seed_delivery(customer_id="c1", amount_cents=12_500, delivered_at=dt.datetime(2026, 9, 14))
    result = CliRunner().invoke(main, ["--dsn", finance_db.dsn, "close-period", "2026-09"])
    assert result.exit_code == 0, result.output
    assert finance_db.journal_total("2150") == 12_500
    assert finance_db.period_locked(dt.date(2026, 9, 1))

    again = CliRunner().invoke(main, ["--dsn", finance_db.dsn, "close-period", "2026-09"])
    assert again.exit_code != 0
    assert "was closed" in again.output
