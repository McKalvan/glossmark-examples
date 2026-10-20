"""Listing model for cassettes."""
from dataclasses import dataclass


@dataclass(frozen=True)
class CassetteListing:
    sku: str
    speeds: int
    range_teeth: tuple[int, int]


# @gloss implements spk:CassetteListing
def range_label(listing: CassetteListing) -> str:
    low, high = listing.range_teeth
    return f"{listing.speeds}-speed {low}-{high}T"
