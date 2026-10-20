"""Pick-wave construction."""


# @gloss implements spk:WaveBuilder
def build_waves(order_ids: list[str], size: int) -> list[list[str]]:
    return [order_ids[i : i + size] for i in range(0, len(order_ids), size)]
