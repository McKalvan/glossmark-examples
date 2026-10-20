-- @gloss represents grid:Tariff
-- One row per tariff and time-of-use band, as priced on the first day of each month.
CREATE TABLE tariff_bands (
    tariff_code   TEXT        NOT NULL,
    band          TEXT        NOT NULL,
    starts_at     TIME        NOT NULL,
    ends_at       TIME        NOT NULL,
    rate_per_kwh  NUMERIC(8,5) NOT NULL,
    valid_from    DATE        NOT NULL,
    PRIMARY KEY (tariff_code, band, valid_from)
);
