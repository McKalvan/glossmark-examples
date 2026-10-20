import click

from hpctl.close_period import close_period


@click.group()
@click.option("--dsn", envvar="HPCTL_DSN", required=True, help="Postgres DSN of the finance database.")
@click.pass_context
def main(ctx, dsn):
    """Harbor Provisions finance operations."""
    ctx.obj = {"dsn": dsn}


main.add_command(close_period)
