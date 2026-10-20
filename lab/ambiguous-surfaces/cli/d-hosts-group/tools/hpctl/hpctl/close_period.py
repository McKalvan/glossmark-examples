import datetime as dt

import click
import psycopg

ACCRUAL_ACCOUNT = "2150"
REVENUE_ACCOUNT = "4000"


# @gloss implements hp:PeriodClose
@click.command("close-period")
@click.argument("month", type=click.DateTime(formats=["%Y-%m"]))
@click.option("--dry-run", is_flag=True, help="Report the accruals without posting or locking.")
@click.pass_obj
def close_period(obj, month, dry_run):
    """Accrue uninvoiced deliveries for MONTH, post them, and lock the period."""
    start = month.date().replace(day=1)
    end = (start + dt.timedelta(days=32)).replace(day=1)
    with psycopg.connect(obj["dsn"]) as conn, conn.transaction():
        locked = conn.execute("SELECT locked_at FROM periods WHERE month = %s FOR UPDATE", (start,)).fetchone()
        if locked is None:
            raise click.ClickException(f"no period {start:%Y-%m}")
        if locked[0] is not None:
            raise click.ClickException(f"period {start:%Y-%m} was closed at {locked[0]:%Y-%m-%d %H:%M}")
        rows = conn.execute(
            """
            SELECT d.customer_id, sum(d.amount_cents)
              FROM deliveries d
              LEFT JOIN invoice_lines il ON il.delivery_id = d.id
             WHERE d.delivered_at >= %s AND d.delivered_at < %s AND il.id IS NULL
             GROUP BY d.customer_id
            """,
            (start, end),
        ).fetchall()
        total = sum(amount for _, amount in rows)
        click.echo(f"{len(rows)} customers, {total / 100:,.2f} USD to accrue for {start:%Y-%m}")
        if dry_run:
            conn.rollback()
            return
        for customer_id, amount in rows:
            conn.execute(
                "INSERT INTO journal (period, account, customer_id, debit_cents, credit_cents, memo)"
                " VALUES (%s, %s, %s, %s, 0, 'accrual'), (%s, %s, %s, 0, %s, 'accrual')",
                (start, ACCRUAL_ACCOUNT, customer_id, amount, start, REVENUE_ACCOUNT, customer_id, amount),
            )
        conn.execute("UPDATE periods SET locked_at = now() WHERE month = %s", (start,))
    click.echo(f"period {start:%Y-%m} closed")
